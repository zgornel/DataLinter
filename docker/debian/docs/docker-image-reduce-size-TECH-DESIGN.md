# Reducing the size of `datalinter-compiled`: design, findings and results

Status: Milestone 1 implemented and verified. Milestone 2 partially done —
`--strip-metadata` implemented and measured; `filter_stdlibs` and the shared
sysimage deferred by choice.
Date: 2026-10-29.

Covers `docker/debian/Dockerfile.datalinter-compiled.debian` (the image published
to ghcr) and `docker/debian/Dockerfile.datalinter-builder.debian` (the
intermediate image, never pushed).

---

## 1. Why

`ghcr.io/zgornel/datalinter-compiled` is the project's shipped artifact: the image
the README tells users to pull, the image the root `datalinter` and
`datalinterserver` wrapper scripts drive, and the default runtime the planned MCP
adapter shells out to (`MCP/docs/plan.md`). Its size is a pull cost for every user.

Both Dockerfiles were single-stage, so every build-time dependency shipped to
users. Two earlier attempts are relevant history:

- `34b7a20` "Reduce Docker image size; fixes #69" removed `gcc g++ make`, and
- `5107559` had to revert that, because tree-sitter compiles grammars lazily *at
  run time* — so the toolchain was a genuine runtime dependency.
- Alpine/musl was tried and abandoned twice (`c0f9ab5`, `31c3be9`, `96e936c`), so
  it is deliberately not part of this design.

All six tree-sitter grammars (r, python, julia, c, c-sharp, javascript) are built
into the image, as before. Making that set selectable at build time was prototyped
and then reverted; see action point A6 if it is revisited.

## 2. Measured baseline

Taken from the published image's manifest and config (not estimated), mapping
every layer to its `created_by`. **Total 1217.67 MB compressed over 22 layers.**

| Layer | Instruction | Compressed |
|---|---|---|
| 1 | `debian:trixie-slim` | 29.36 MB |
| 2, 16 | two uncleaned `apt-get update` list layers | 33.69 MB |
| 3 | apt install `ca-certificates git wget gcc g++ jq curl make tar gzip libxml2 dpkg` | **136.96 MB** |
| 5 | `COPY ./build/datalinter` | **295.27 MB** |
| 6 | `COPY ./build/datalinterserver` | **296.25 MB** |
| 18 | apt install `libtree-sitter0.26 tree-sitter-cli` (no `--no-install-recommends`) | **105.38 MB** |
| 20, 21 | 6 × grammar `git clone` + `tree-sitter generate` | **320.41 MB** |
| 4, 7–14, 15, 17, 19, 22 | mkdir, knowledge ×2, config ×2, test fixtures, ParSitter, sid list/pin, autoremove | 0.35 MB |

Non-bundle layers total **625.96 MB**; the two app bundles total **591.52 MB**.

### Two baseline facts that reordered the priorities

1. **The grammar clones were the single largest item** at 320.41 MB — larger than
   either app bundle — and almost entirely `.git`. GitHub's packed sizes (r 27,
   python 23, julia 77, c 20, c-sharp 127, javascript 43 MB) account for layers
   20+21 almost exactly. Nothing in the image needs those histories.
2. **All four "priming" `RUN`s were dead.** They are recorded `"empty_layer": true`
   — they wrote nothing. They also ran *before* tree-sitter was installed, so no
   parser existed while they ran, and the `datalinterserver` one ended in `&`,
   backgrounding a process into a layer that immediately exited.

## 3. Design

Three stages. BuildKit runs the first two in parallel; no `RUN --mount` is used, so
the legacy builder works too.

### Stage `apps` — deduplicate the two bundles

Both PackageCompiler bundles carry a private copy of the same Julia runtime
(libjulia, libLLVM, libopenblas, the stdlib shared objects), and identical
`knowledge/` and `config/` trees. The stage stages both bundles and runs
`rdfind -makehardlinks true` across them. The sysimages differ and are untouched.

**The constraint that makes or breaks this:** hardlinks are preserved per *source
path*, not per instruction. BuildKit's copy is `tonistiigi/fsutil/copy`, whose
inode map is created per copier invocation, and the Dockerfile frontend emits one
`FileActionCopy` per source. So the final stage must use

```dockerfile
COPY --from=apps /out/apps/ /
```

Two `COPY --from` lines — or one line with two sources — silently lose the sharing.
Corollaries:

- The dedup must happen in the stage that *produces* the copied layer. Hardlinking
  in a `RUN` in the final stage is a net **loss**: on overlayfs the lower layer
  still holds both copies and copy-up adds a third.
- Never `chmod -R`, `chown -R` or `touch` over `/datalinter*` after the COPY, and
  don't use `COPY --chown` as a substitute for getting ownership right in `apps`.
- `COPY --link` is avoided; it changes layer construction for marginal benefit.

**Hardlinks, not symlinks.** glibc's `_dl_new_object` (`elf/dl-object.c`) derives
`$ORIGIN` lexically from the path a library was opened with, but the main
executable is resolved via `/proc/self/exe`, which *does* follow symlinks — so
symlinking `/datalinterserver/bin/datalinterserver` would load the wrong sysimage.
Hardlinks do not involve the loader at all.

### Stage `prep` — grammars and a pre-compiled parser cache

ParSitter does not link libtree-sitter; it shells out to
`tree-sitter parse -q -x --scope <scope> <file>`
(`ParSitter/src/parse.jl`, `_make_parse_file_cmd`). The CLI compiles each grammar
into a shared object lazily on first parse and caches it. Pre-compiling those
objects at build time is what allows the final image to ship without a compiler.

- Sid repo (tree-sitter 0.26 is not in Trixie) added, pinned, used and dropped in
  one layer.
- `nodejs` is installed **explicitly**. It was previously arriving as an
  unrequested `Recommends` of `tree-sitter-cli` — which is where layer 18's 105 MB
  came from — but `tree-sitter generate` shells out to node
  (`crates/generate/src/generate.rs`: `js_runtime.unwrap_or("node")`). Adding
  `--no-install-recommends` *without* naming nodejs breaks `generate`. (Alternative
  if node is ever unwanted: `tree-sitter generate src/grammar.json` reads the
  committed JSON directly and needs no JS runtime.)
- Grammars cloned `--depth 1 --filter=blob:none`.
- `tree-sitter.json` and `src/parser.c` are asserted present before pruning, so a
  grammar repo changing layout fails the build with a clear message.
- `TREE_SITTER_DIR` and `TREE_SITTER_LIBDIR` are set explicitly, and `config.json`
  is written by hand rather than via `tree-sitter init-config` (whose output embeds
  the build user's home). This also means `docker run --user 1000` no longer
  silently loses all parsing through `HOME`/XDG lookup.

Order within the stage is **generate → warm → prune → pin mtimes** (see §4.1).

`docker/debian/smoke/` holds one minimal valid snippet per grammar plus
`scopes.txt`, which maps each tree-sitter scope to its sample. It is used to
pre-compile the parsers and, in the final stage, to verify them.

### Final stage

`ca-certificates libxml2 libgcc-s1` only. Absent: `gcc g++ make git wget curl jq`,
both sets of apt lists, the Sid sources list and pin, and `libtree-sitter0.26`.

`libtree-sitter0.26` is not needed because `tree-sitter-cli` 0.26.11-1 depends only
on `libc6 (>= 2.39)` and `libgcc-s1` (Trixie has 2.41), links tree-sitter
statically, and ParSitter never `ccall`s or `dlopen`s the C library. The ~8 MB
binary is copied from `prep` instead, which keeps the Sid resolver out of the
shipped image entirely. Trade-off: no `dpkg -l` entry for SBOM scanning; if that
is ever required, `apt-get download` in `prep` and `dpkg -i` the single `.deb`.

The four dead priming `RUN`s are deleted, which also removes the only reason
`/tmp/test` was on the critical path (the fixtures still ship, because
`docs/src/examples.md:253` references `/tmp/test/data/imbalanced_data.csv`, and
326 K is noise).

### The build-time gate

The final stage ends with a `RUN` that asserts no compiler is present, that no
stale lock directory shipped, and that **every** scope parses to non-empty output —
the five ParSitter scopes plus `source.js`, and additionally the real
`test/code` R and Python snippets.

Because no C compiler exists at that point, a missing or stale parser object, an
over-pruned grammar or an unresolvable scope all **fail the build** instead of
shipping an image that breaks on first use. This is precisely the check that was
missing when `34b7a20` removed gcc and `5107559` had to revert it.

An empty result with exit code 0 is the signature of a parser-directory miss, which
ParSitter swallows as an empty parse — hence the gate asserts non-empty output, not
just exit status.

## 4. Findings

### 4.1 Pruning must happen *after* the cache is warmed (correction to the plan)

The plan listed `src/tree_sitter/*.h` as safely prunable, which is true at run time
but not at build time: they are the include path for compiling `parser.c`. Pruning
before warming fails with

```
/root/dev/tree-sitter-r/./src/parser.c:3:10: fatal error: tree_sitter/parser.h: No such file or directory
```

The stage order is therefore generate → warm → prune, and the Dockerfile carries a
comment to stop it being reordered back.

### 4.2 The parser cache, and what keeps it valid

From `crates/loader/src/loader.rs` (v0.26.x), confirmed against the built image:

- Cache path is `$TREE_SITTER_LIBDIR`, else `~/.cache/tree-sitter/lib`.
- Filenames are the bare grammar name from `tree-sitter.json`, with no version or
  flags hash. Note the real names use underscores: **`c_sharp.so`**, not
  `c-sharp.so`.
- Recompilation is triggered when the object is missing, or when
  `mtime(src/parser.c | src/scanner.c) > mtime(<name>.so)`. The comparison is
  strictly `>`, so equal timestamps are safe — which also makes a
  `SOURCE_DATE_EPOCH` build safe.
- `src/parser.c` **must exist**: the CLI stats it on every parse and has no
  fallback to an existing object. Its *contents* are no longer read once the
  object exists, but the file cannot be deleted.
- `COPY --from` does not reset mtimes (`fsutil/copy/copy_unix.go` applies the
  source times via `UtimesNanoAt` unless timestamp rewriting is enabled), and layer
  tars carry mtimes through push/pull.

Mitigation implemented anyway, so the invariant holds regardless of builder
behaviour: sources are pinned to `2020-01-01` and objects to `2020-01-02`, and the
parser objects are the last tree-sitter artefact copied in the final stage.

**Verified load-bearing.** Touching `parser.c` newer than its object inside the
finished image makes the parse fail with `Failed to load language`. So the mtime
pinning is doing real work and the gate would catch a regression.

### 4.3 The lock-file hazard was overstated (correction to the plan)

The plan asserted that a lock file baked into the image is older than the loader's
30-second threshold and therefore *guarantees* a forced recompile — fatal without a
compiler. Planting a stale `lock/r.lock` in the finished image and parsing
succeeded anyway. The `rm -rf` of the lock directory and the gate's `test ! -e`
remain as cheap hygiene, but this is not the trap it was described as.

### 4.4 What each grammar directory must keep

`tree-sitter.json` (the only manifest `parse` consults — `package.json` is never
read), plus `src/parser.c`, `src/scanner.c` where present, and `src/grammar.json`
as a name fallback. The container directory entries must keep their
`tree-sitter-` prefix (the scan is non-recursive and only descends into those), and
`/root/.config/tree-sitter/config.json` must remain. `queries/` is read only by the
`highlight` and `tags` subcommands. Everything else — `.git`, `bindings/`, test
corpora, `examples/`, `docs/`, build files — is prunable.

### 4.5 Unplanned win: first-parse latency

Parser objects were previously compiled into each *container's* writable layer, so
**every fresh `docker run` recompiled them on first parse** — c-sharp's `parser.c`
is 32 MB and julia's 24 MB, at `-O2`. That cost is now paid once at build time.

### 4.6 Generated parser sources compress ~20:1

Measured while prototyping the (since reverted) language selection: dropping four
of six grammars removed 73.3 MB uncompressed but only **3.7 MB compressed**.
Generated `parser.c` tables are highly repetitive, so they are cheap to *pull* and
expensive to *store*. By contrast the 320 MB of `.git` that dominated the baseline
was already-compressed packfiles, which is why removing it moved the compressed
number so much. Relevant to A3, and to any future decision about which grammars
to ship.

### 4.7 `--strip-metadata` is safe here, but it was worth testing properly

`src/config.jl:70` discovers each linter's keyword arguments **at run time**:

```julia
f_kwargs = unique(v for v in vcat(Base.kwarg_decl.(methods(linter.f))...) if !in(v, SKIP_KWARGS))
```

and then keeps only the config `[parameters]` entries whose names appear in
`f_kwargs`. Those names come from method slot names, which is exactly the kind of
metadata `--strip-metadata` targets. Had it stripped them, `linter_kwargs` would
have come back empty and **every linter would have silently fallen back to default
parameters, ignoring the user's config** — and the mismatch is reported only via
`@debug`, so at default log level it would have been invisible. A silent
wrong-results mode, not a crash.

Tested with a differential: two configs identical except
`[parameters.large_outliers] tukey_fences_k`, set to 0.001 and 100000.0, run
against `test/data/data.csv` (which has obvious outliers). The baseline build
produced different output for the two configs, proving the test is sensitive; the
stripped build produced *the same two different outputs*, byte for byte. So slot
names survive `--strip-metadata` in Julia 1.12.5 and the reflection path is intact.

This is the test to re-run before adopting `--strip-ir` (task 2.6) or
`filter_stdlibs` (task 2.2), both of which are likelier to disturb it.

## 5. Results

### 5.1 Verified by building

`prep`, the builder image, and a full end-to-end build of the compiled image (with
stand-in app bundles, since `./build/` only exists after the builder runs in CI)
all build successfully.

| Check | Result |
|---|---|
| All six grammars parse, no compiler present | pass |
| Same under `--read-only --tmpfs /tmp` (cannot be compiled into, so this proves the cache is genuinely warm) | pass |
| Negative test: `parser.c` newer than its object | parse fails as designed |
| Negative test: planted stale lock file | tolerated — see §4.3 |
| Hardlinks survive into the shipped image | same inode, `nlink=2` |
| Distinct sysimages not linked | `nlink=1` |
| `/datalinter/config` contents, all documented mount points | intact |
| Builder image: Julia 1.12.5, tree-sitter 0.26.11, node v20.19.2, 6 parsers warm, no tarball resident | pass |

**The single-COPY constraint, measured.** Identical 20 MB payload shared between
two directories:

| Variant | nlink | Payload | Image size |
|---|---|---|---|
| one `COPY --from` of the parent dir | 2 | 20 MB | 98,864,241 B |
| two separate `COPY --from` lines | 1 | 39 MB | 118,864,241 B |

Exactly 20,000,000 bytes of difference — the whole shared payload, lost.

### 5.2 Size

Everything the new image ships **except** the two app bundles:

| Component | Uncompressed |
|---|---|
| `debian:trixie-slim` base | 78.9 MB |
| runtime apt (`ca-certificates libxml2 libgcc-s1`) | 5.43 MB |
| `tree-sitter` CLI binary | 8.12 MB |
| pruned grammars (`/root/dev`, 4 files each) | 71.5 MB |
| warm parser cache (6 objects) | 10.6 MB |
| config, test fixtures, smoke fixtures | ~1 MB |
| **total** | **174.5 MB → 39.4 MB compressed** |

The same set of layers in the published image totals **625.96 MB compressed**.

| | Compressed |
|---|---|
| Baseline, published | 1217.67 MB |
| Non-bundle payload, before → after | 625.96 → 39.4 MB |
| Two app bundles, as built | 591.0 MB |
| Two app bundles, hardlink-deduped | 472.7 MB |
| Two app bundles, deduped + `--strip-metadata` | 413.0 MB |
| **Total after Milestone 1** | **512.1 MB (−57.9%)** |
| **Total after Milestone 1 + task 2.3** | **452.4 MB (−62.8%)** |

Every figure above is measured. The dedup ratio was initially estimated from
stand-in bundles (46 MB collapsing to 27 MB, 20 files linked, which included the
duplicated `knowledge/` and `config/` trees); it has since been measured on the
real bundles at 118.3 MB compressed (§5.4). The CI step still prints it per build,
as a regression guard.

### 5.3 Files changed

- `docker/debian/Dockerfile.datalinter-compiled.debian` — rewritten, three stages,
  build-time gate.
- `docker/debian/Dockerfile.datalinter-builder.debian` — Julia
  download/unpack/delete collapsed into one layer (the ~290 MB tarball was staying
  resident because the `rm` was in a later layer), Sid repo added-used-dropped in
  one layer, explicit `nodejs`, shallow clones, parsers pre-compiled so
  `Pkg.test()` and the app build do not pay for them. New builder image: 1.698 GB
  uncompressed, never pushed.
- `docker/debian/smoke/` — minimal valid snippets plus `scopes.txt`, used to warm
  the cache and to run the gate.
- `.github/workflows/ci.yml` — new `report_datalinter-compiled_image_size` step
  prints size and layer breakdown, and **fails** if no hardlinks survived.
- `.gitattributes` — pins LF for `docker/**`. See action point A4.

### 5.4 Milestone 2: `--strip-metadata`, measured

Built twice in the builder image on this machine — once with the unmodified
`build.jl`, once with the patched one — sharing a warm depot so the only
difference is the flag.

| Variant | Raw | gzip | + hardlink dedup, raw | + dedup, gzip |
|---|---|---|---|---|
| as built today | 2218.2 MB | **591.0 MB** | 1859.9 MB | 472.7 MB |
| `--strip-metadata` | 1970.3 MB | 531.3 MB | 1611.9 MB | **413.0 MB** |

- `sys.so`: **749.2 → 625.5 MB** per bundle (−16.5%); the server bundle's goes
  752.4 → 628.2 MB.
- Hardlink dedup on the real bundles: **358 MiB raw / 118.3 MB compressed**,
  928 links over 1600 files. This replaces the earlier 100–150 MB estimate and
  closes action point A1 without waiting for CI.
- `--strip-metadata` on top of dedup: **−59.7 MB compressed**.

**Method cross-check:** the bundles as built here tar+gzip to 591.0 MB, against
591.52 MB for the same two layers in the published manifest — so these local
numbers are directly comparable to the baseline in §2.

**Correctness, baseline vs stripped — all byte-identical:**

| Check | Result |
|---|---|
| Runtime kwarg discovery honours `tukey_fences_k` (§4.7) | both builds honour it |
| Data linting output, two different configs | byte-identical |
| R code linting through ParSitter + tree-sitter | byte-identical |
| Python code linting | byte-identical |
| `datalinter --help` (ArgParse) | byte-identical |
| `datalinterserver --help` | byte-identical |

**Incidental finding:** each bundle ships a **54 MB `thrift` executable** under
`share/julia/artifacts/` (a Parquet/Thrift_jll artifact). Dedup collapses the
second copy, but whether the CLI binary is needed at run time at all is worth
checking — see action point A9.

## 6. Remaining action points

### Milestone 1 follow-ups

- **A1 — Confirm the real dedup ratio.** The first CI run after this change prints
  `hard-linked files across the two bundles` and the image size. If the count is 0
  the build fails; if the saving is far below ~100 MB, the two bundles share less
  than expected and Milestone 2 item B3 becomes the main lever.
- **A2 — Set a size threshold in CI.** The reporting step deliberately has no
  numeric gate yet, because the post-change uncompressed size is not yet known.
  Once the first run reports it, add a `test` against a committed ceiling so 320 MB
  of `.git` cannot creep back in.
- **A3 — Optional: truncate `parser.c` after warming.** The loader only stats it
  (§4.2), so its content is dead weight: 69 MB uncompressed, roughly 10 MB
  compressed (§4.6). Judged not worth the cleverness, but it is the next easy
  non-bundle byte if on-disk size matters more than clarity.
- **A4 — `.gitattributes` needs `git add -f`.** This repo's `.gitignore` has a `.*`
  rule, so the file is ignored. Not critical: `scopes.txt` is read through
  `tr -d '\r'`, so CRLF safety does not depend on it.
- **A5 — `.dockerignore` (optional, zero image bytes).** Worth it for
  context-transfer time, since the compiled build tars `./build` plus `.git`. It
  must **not** exclude `.git` — the builder does `COPY ./.git ./.git/` and the
  build would fail. Both Dockerfiles share one context, so any ignore file must
  satisfy the union of their needs.
- **A6 — Build-time language selection, if revisited.** A `DATALINTER_LANGUAGES`
  build argument driven by a `languages.tsv` manifest was implemented and verified
  (unknown and empty selections rejected; an `r python` build produced exactly two
  grammars and two parsers), then reverted on request. Two things that work would
  have to be rebuilt if it returns:
  - the manifest has to drive all four consumers — cloning, cache warming, the
    gate, and ParSitter — or they drift apart;
  - ParSitter's `__init__()` rebuilds `LANGUAGE_MAP` from
    `ParSitter/languages/*.toml` on **every app start** (`src/ParSitter.jl:13`,
    `src/utils.jl:75`), reading the shipped depot copy rather than a value baked
    into the sysimage. So a narrower image must also set `enabled = false` for the
    languages it drops, or it will advertise them and then fail at parse time.

    Note the payoff is mostly on-disk, not pull size (§4.6).
- **A7 — Unrelated doc bug, noticed while checking the contract.**
  `docs/src/examples.md:36` documents `/datalinterserver/datalinterserver`; the
  binary is at `/datalinterserver/bin/datalinterserver`. Pre-existing, left alone.
- **A8 — Expected harmless regression.** `src/version.jl` shells out to `git`, now
  absent. It was already a no-op in the compiled image (the `try`/`catch` returns
  empty strings), but confirm with `--version` before and after rather than
  assuming.

### Milestone 2 — the app bundles

**Done: `--strip-metadata` (§5.4).** Implemented as a patch to
`zgornel/julia_app_builder`, since that repo owns the `create_app` call. Measured
−59.7 MB compressed, with byte-identical output across every check.

Remaining levers, in increasing order of risk:

- **B1 / task 2.2 — `filter_stdlibs=true`.** Drops unused stdlibs from each
  sysimage. The documented caveats are real (a package can use
  `Random`/`LinearAlgebra` without declaring it), and the failure mode is a runtime
  `MethodError` in a rarely-hit linter, so it needs a full functional pass over all
  linters. Deferred by choice.
- **B2b / task 2.6 — `--strip-ir` on top of `--strip-metadata`.** Removes the IR
  needed to compile new specializations at run time. Higher risk here than the
  plan assumed, because `src/config.jl:70` does runtime reflection over method
  signatures (§5.4).
- **New / task 2.5 — `compress_sysimage`.** PackageCompiler 2.4.5's `create_app`
  accepts this keyword; it was not in the original plan and is not yet evaluated.
  With `sys.so` still 625.5 MB per bundle after stripping, it is the most
  promising untried lever. Needs a startup-latency measurement, since the sysimage
  would be decompressed on load.
- **B3 / task 2.4 — one shared sysimage**, via
  `create_app(..., executables=["datalinter"=>"julia_main", "datalinterserver"=>"server_main"])`.
  Still the largest remaining item, but **smaller than the plan estimated**: at
  ~290 MB the plan assumed a whole duplicated bundle, whereas hardlink dedup
  already collapses everything the two bundles share. What remains unique is
  `sys.so` (625.5 MB raw each after stripping), so a single shared sysimage is
  worth roughly **155 MB compressed**, not 290. It requires merging
  `apps/datalinter` and `apps/datalinterserver` into one package (separate
  `Project.toml`s today with different dependency sets, each calling
  `Base.set_active_project`), and preserving the documented paths by making
  `/datalinterserver` a directory symlink — the one place where `/proc/self/exe`
  symlink resolution works *for* us rather than against us (§3).

**Note on the external repo.** `build.jl` has a latent bug worth fixing while
there: `build_targets = filter(!isdir, readdir(apps_path))` is meant to exclude
directories, but `isdir` resolves the bare names against the process's current
working directory rather than `apps_path`, so both app directories pass a filter
designed to reject them. It works only because the relative paths do not resolve.
Left alone in the patch to keep the diff minimal.

## 7. How to re-verify

```bash
# size and layers
docker build --no-cache -f docker/debian/Dockerfile.datalinter-compiled.debian -t dl:new .
docker image inspect -f '{{.Size}}' dl:new
docker history --format '{{.Size}}  {{.CreatedBy}}' dl:new

# hardlinks survived (nlink must be >1 on the shared runtime libs)
docker run --rm dl:new sh -c 'find /datalinter /datalinterserver -xdev -type f -links +1 | wc -l'
docker run --rm dl:new sh -c 'stat -c "%i %h %n" /datalinter/lib/julia/libjulia-internal.so /datalinterserver/lib/julia/libjulia-internal.so'

# warm cache, no compiler
docker run --rm dl:new sh -c 'for c in cc gcc g++ make git; do ! command -v $c; done && echo clean'
docker run --rm dl:new sh -c 'for g in r python julia c c_sharp javascript; do stat -c "%Y %n" /root/.cache/tree-sitter/lib/$g.so; done'
docker run --rm dl:new ldd /usr/bin/tree-sitter

# read-only proof: nothing can be compiled, so success means the cache is warm
docker run --rm --read-only --tmpfs /tmp dl:new sh -c \
  'printf "x <- 1\n" > /tmp/t.R && tree-sitter parse -q -x --scope source.R /tmp/t.R | head -c 200'

# documented contract
docker run --rm dl:new /datalinter/bin/datalinter --help
docker run --rm dl:new ls -l /datalinter/config
docker run --rm dl:new /datalinter/bin/datalinter /tmp/test/data/imbalanced_data.csv \
  --code-path /tmp/test/code/r_snippet_imbalanced.r --config-path /tmp/test/test_config.toml
```

Plus the server flow and the mount-based invocations from `docs/src/examples.md`,
and a `.py` `--code-path` to exercise a second grammar through ParSitter.

Only the `prep` stage can be built without `./build/`; use
`docker build --target prep` for a fast check of the grammar and cache work.

## 8. Reference

- `crates/loader/src/loader.rs`, `crates/generate/src/generate.rs` (tree-sitter v0.26)
- `tonistiigi/fsutil` `copy/copy.go`, `copy/copy_unix.go` (BuildKit copy semantics)
- glibc `elf/dl-object.c`, `elf/dl-load.c` (`$ORIGIN` resolution)
- `ParSitter/src/parse.jl` (`_make_parse_file_cmd`), `src/ParSitter.jl` (`__init__`),
  `src/utils.jl` (`enabled` handling), `languages/*.toml` — the authority on the
  five scopes the warm cache must satisfy (`source.c`, `source.cs`, `source.julia`,
  `source.python`, `source.R`)
- `PackageCompiler.jl` app docs, for Milestone 2
