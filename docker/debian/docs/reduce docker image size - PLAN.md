# Reduce the size of `ghcr.io/zgornel/datalinter-compiled`

## Context

`ghcr.io/zgornel/datalinter-compiled` is the shipped artifact of this project — the
image the README tells users to pull, the thing the root `datalinter` /
`datalinterserver` wrapper scripts drive, and (per `MCP/docs/plan.md:271`) the
default runtime the planned MCP adapter will shell out to. Image size is about to
become a pull cost for every MCP user.

The published image is **1218 MB compressed across 22 layers**. Most of that is
accidental: 320 MB of `.git` history inside cloned tree-sitter grammars, 276 MB of
build-only toolchain and apt lists, and two PackageCompiler app bundles that each
carry a private copy of the same Julia runtime. Both Dockerfiles are single-stage,
so every build-time dependency ships to users. Past attempts went at this twice —
`34b7a20` ("Reduce Docker image size; fixes #69") removed gcc and was reverted by
`5107559` because tree-sitter compiles grammars lazily _at runtime_; Alpine was
tried and abandoned (`c0f9ab5`, `31c3be9`, `96e936c`).

Intended outcome: **~1218 MB → ~500–560 MB (−55%)** in Milestone 1, using only
changes in this repo, with no change to the documented container contract. The
remaining dominant term (one whole duplicated Julia runtime) needs the external
builder and is Milestone 2.

### Measured baseline (from the published manifest, not estimates)

| Layer    | Instruction                                                                     | Compressed   |
| -------- | ------------------------------------------------------------------------------- | ------------ |
| 1        | `debian:trixie-slim`                                                            | 29.4 MB      |
| 2, 16    | two uncleaned `apt-get update` list layers                                      | 33.7 MB      |
| 3        | apt install `git wget gcc g++ jq curl make tar gzip dpkg …`                     | **137.0 MB** |
| 5        | `COPY ./build/datalinter`                                                       | **295.3 MB** |
| 6        | `COPY ./build/datalinterserver`                                                 | **296.3 MB** |
| 18       | apt install `libtree-sitter0.26 tree-sitter-cli` (no `--no-install-recommends`) | **105.4 MB** |
| 20, 21   | 6 × grammar `git clone` + `tree-sitter generate`                                | **320.4 MB** |
| 7–14, 22 | knowledge ×2, config ×2, test fixtures, ParSitter, autoremove                   | 0.35 MB      |

Two findings that reorder the priorities:

- The six grammar clones are 26% of the image and are **the cheapest thing to
  fix** — GitHub's packed sizes (r 27, python 23, julia 77, c 20, c-sharp 127,
  javascript 43 MB) account for layers 20+21 almost exactly. It is all `.git`.
- All four "priming" `RUN`s are recorded `"empty_layer": true`. They write
  nothing, warm nothing, and run _before_ tree-sitter is installed (line 77), so
  no parser exists while they run. They are dead weight, not an optimization.

### Decisions recorded

- Two milestones: M1 this repo only, M2 the external `julia_app_builder`.
- Remove gcc/g++/make from the shipped image, gated by a build-time proof that
  fails the build rather than shipping a broken image (the `5107559` failure mode).
- Keep the `javascript` grammar for future language support; prune `.git`,
  bindings and test corpora from all six. (Pruning captures ~all of the 320 MB
  regardless, so keeping JS costs little.)

---

# Milestone 1 — this repo (~1218 → ~500–560 MB)

Ranked by compressed bytes saved ÷ risk.

| #   | Measure                                                                        | Saving              | Risk             |
| --- | ------------------------------------------------------------------------------ | ------------------- | ---------------- |
| 1   | Shallow/blobless grammar clones + prune to the files the loader actually reads | **~290 MB**         | very low         |
| 2   | Multi-stage: no gcc/g++/make/git/wget/curl/jq, no apt lists, no sid repo       | **~265 MB**         | medium, needs #3 |
| 3   | Pre-compile the parser `.so`s at build time + fail-fast gate                   | −15 MB (adds bytes) | enabler for #2   |
| 4   | Hardlink-dedup the two app bundles                                             | **~100–150 MB**     | low–medium       |
| 5   | Drop the 4 dead priming `RUN`s                                                 | 0 bytes             | none             |

## 1.1 Restructure `docker/debian/Dockerfile.datalinter-compiled.debian` into 3 stages

BuildKit runs the first two in parallel.

### Stage `apps` — bundle dedup

- One `RUN`: `apt-get install --no-install-recommends rdfind` + `rm -rf /var/lib/apt/lists/*`.
- `COPY ./build/datalinter /out/apps/datalinter` and
  `COPY ./build/datalinterserver /out/apps/datalinterserver`, then the existing
  `knowledge`/`config` copies into both (keeps the documented `/datalinter/config`).
- `RUN rdfind -makehardlinks true -outputname /dev/null /out/apps/datalinter /out/apps/datalinterserver`
  — collapses the shared Julia runtime libs (libjulia, libLLVM, libopenblas,
  stdlib `.so`s). The two sysimages differ and are untouched.
- Scope the dedup to `/out/apps` only. Do **not** let it touch the grammar or
  parser-cache trees, where mtimes are load-bearing (§1.2).

**The constraint that decides whether this works:** hardlinks are preserved per
_source path_, not per instruction. BuildKit's copy is `tonistiigi/fsutil/copy`,
whose inode map (`c.inodes`) is created per `newCopier` call, and the Dockerfile
frontend emits one `FileActionCopy` per source. So two `COPY --from` lines, or one
line with two sources, both **lose the sharing**. The final stage must use a single
source directory:

```dockerfile
COPY --from=apps /out/apps/ /
```

Two corollaries:

- The dedup must happen in the stage that _produces_ the layer. Hardlinking in a
  `RUN` in the final stage is a net **loss** — on overlayfs the lower layer still
  holds both copies and copy-up adds a third.
- Never `chmod -R`/`chown -R`/`touch` over `/datalinter*` after the COPY, and don't
  use `COPY --chown` as a substitute for getting ownership right in `apps`.
- Avoid `COPY --link` here; it changes layer construction for marginal benefit.

Hardlinks, not symlinks: glibc's `_dl_new_object` (`elf/dl-object.c`) derives
`$ORIGIN` _lexically_ from the path used to open a library, but the main executable
is resolved via `/proc/self/exe`, which **does** follow symlinks — so symlinking
`/datalinterserver/bin/datalinterserver` would load the wrong sysimage. Hardlinks
don't involve the loader at all.

### Stage `prep` — toolchain lives and dies here

- One `RUN`: add the sid list + pin, `apt-get update`, install
  `--no-install-recommends ca-certificates git gcc g++ make nodejs libtree-sitter0.26 tree-sitter-cli`,
  then remove the sid list/pin and `rm -rf /var/lib/apt/lists/*`.
- `ENV TREE_SITTER_DIR=/root/.config/tree-sitter TREE_SITTER_LIBDIR=/root/.cache/tree-sitter/lib`.
  Write `config.json` explicitly as `{"parser-directories": ["/root/dev"]}` rather
  than using `tree-sitter init-config`, whose output embeds the build user's home.
- Clone the six grammars with `git clone --depth 1 --filter=blob:none`
  (`r` from r-lib, `python julia c c-sharp javascript` from tree-sitter),
  `tree-sitter generate`, then prune each to `tree-sitter.json`, `src/parser.c`,
  `src/scanner.c` (where present) and `src/grammar.json`; `rm -rf .git bindings
test examples docs queries binding.gyp Cargo.* package*.json Makefile`.
- **Warm the cache:** one `tree-sitter parse -q -x --scope <scope>` per grammar
  against a trivial snippet (`x <- 1`, `x = 1`, `x = 1`, `int main(){return 0;}`,
  `class A{}`, `var x=1`), which is what compiles each `.so`.
- Normalise mtimes so `parser.c`/`scanner.c` are strictly older than the `.so`,
  then `rm -rf /root/.cache/tree-sitter/lock` (§1.2).
- Stage into `/out/ts/{grammars,lib,config}` plus `/out/smoke/` for the gate.

**The trap:** `tree-sitter-cli` is currently installed _without_
`--no-install-recommends`, which is where layer 18's 105 MB comes from — but its
recommends include `nodejs`, and `tree-sitter generate` shells out to it
(`crates/generate/src/generate.rs`: `js_runtime.unwrap_or("node")`). Adding
`--no-install-recommends` alone **breaks `generate` with a confusing error**. Hence
the explicit `nodejs` above (trixie's; never reaches the final image). Alternative
if you'd rather skip node entirely: `tree-sitter generate src/grammar.json` reads
the committed JSON directly — all six repos commit it.

### Final stage

- One `RUN`: `apt-get install --no-install-recommends ca-certificates libxml2 libgcc-s1`
  - `rm -rf /var/lib/apt/lists/*`. One `mkdir -p` for the documented mount points.
- Same two `ENV TREE_SITTER_*` lines (pins lookup so `docker run --user 1000`
  doesn't silently lose all parsing via `HOME`/XDG).
- `COPY --from=apps /out/apps/ /` — single source path, hardlinks intact.
- `COPY --from=prep /usr/bin/tree-sitter /usr/bin/`, then the grammars, then the
  config, and **last** `/out/ts/lib/ /root/.cache/tree-sitter/lib/`.
- Test fixtures stay (`docs/src/examples.md:253` references
  `/tmp/test/data/imbalanced_data.csv`; 326 K is noise).
- `COPY ./julia_packages/ParSitter /root/.julia/packages/ParSitter` unchanged — the
  app's baked `@__FILE__` path depends on the version-slug layout.
- The verification `RUN` from §1.3. `WORKDIR /`, still no `ENTRYPOINT`.
- **Delete the four priming `RUN`s** (lines 55–64) — empty layers that run before
  tree-sitter exists, one of which backgrounds with `&` into a dying layer.

`libtree-sitter0.26` is **not needed in the final image**: `tree-sitter-cli`
0.26.11-1 depends only on `libc6 (>= 2.39)` and `libgcc-s1` (trixie has 2.41), the
Rust library is linked statically, and ParSitter never `ccall`s or `dlopen`s it —
it shells out to `tree-sitter parse`. Copying the 8 MB binary also removes the sid
resolver from the shipped image entirely. Trade-off: no `dpkg -l` entry for SBOM
scanning; if that matters, `apt-get download` in prep and `dpkg -i` the single
`.deb` in the final stage.

## 1.2 Why the warm cache survives, and the one thing that would break it

From `crates/loader/src/loader.rs` (v0.26.x):

- Cache is `$TREE_SITTER_LIBDIR` else `~/.cache/tree-sitter/lib`, filenames are
  bare `<grammar name>.so` with no version/flags hash — don't rename them.
- `needs_recompile` rebuilds if the `.so` is missing or if `mtime(src/parser.c
| src/scanner.c | external-files) > mtime(lib)`. Strictly greater, so equal
  timestamps are safe.
- **`src/parser.c` must exist** — if it's missing, `mtime()` fails and surfaces as
  _"Failed to compare source and binary timestamps"_ with no fallback to the
  existing `.so`. This rules out deleting `src/`.
- **The lock file is the real trap.** After the staleness check the loader opens
  `<cache>/tree-sitter/lock/<name>.lock` _without_ create; if that open succeeds
  and the file is older than 30 s, it forces `recompile = true`. A lock file baked
  into an image is always older than 30 s, so shipping one **guarantees** a runtime
  recompile — fatal in a compiler-less image. If it's absent the branch is skipped
  silently. Hence the explicit `rm -rf`.

`COPY --from` does **not** reset mtimes (`fsutil/copy/copy_unix.go` applies source
times via `UtimesNanoAt` unless `SOURCE_DATE_EPOCH`/`rewrite-timestamp` is set, and
that case sets them all equal, which is also safe). Layer tars carry mtimes and
push/pull preserves both them and the hardlinks (containerd's `ChangeWriter` emits
`tar.TypeLink` with `Size = 0`).

The grammar dir must keep `tree-sitter.json` (the only manifest `parse` reads —
never `package.json`), `src/parser.c`, `src/scanner.c`, and `src/grammar.json` as a
name fallback. `queries/` is only read by the `highlight`/`tags` subcommands.
`/root/.config/tree-sitter/config.json` **must** remain — without parser
directories the loader only _warns_, which ParSitter swallows as an empty parse.
Directory names must keep the `tree-sitter-` prefix (the scan is non-recursive and
only descends into those).

**Bonus worth advertising:** today the `.so` is compiled lazily into each
_container's_ writable layer, so every fresh `docker run` recompiles on first parse
— including c-sharp's 32 MB and julia's 24 MB `parser.c` at `-O2`. Warming at build
time removes tens of seconds of first-parse latency per container.

## 1.3 The build-time proof (this is what makes dropping gcc safe)

In the **final** stage, so it runs against the real published filesystem:

```dockerfile
RUN --mount=type=bind,from=prep,source=/out/smoke,target=/smoke \
    --mount=type=tmpfs,target=/smoketmp \
    set -eux; \
    for c in cc gcc g++ make git; do ! command -v "$c"; done; \
    test ! -e "${TREE_SITTER_LIBDIR%/lib}/lock"; \
    for s in source.R:r.R source.python:p.py source.julia:j.jl \
             source.c:c.c source.cs:cs.cs source.js:j.js; do \
      tree-sitter parse -q -x --scope "${s%%:*}" "/smoke/${s#*:}" > /dev/null; \
    done
```

With no C compiler present, a missing or stale `.so`, a stale lock, a pruned
`parser.c` or an unresolvable scope all **fail the build**. The `--mount` forms keep
fixtures and temp files out of the image. The five ParSitter scopes come from
`~/.julia/packages/ParSitter/vBdbf/languages/*.toml` (`c cs julia python r`);
`source.js` is included so the retained JS grammar is actually usable.

## 1.4 Builder Dockerfile hygiene (CI time/disk only — never pushed)

In `docker/debian/Dockerfile.datalinter-builder.debian`: collapse the Julia
download/untar/`ln -s`/`rm` into one `RUN` (the ~290 MB tarball is currently still
resident because the `rm` is a later layer), collapse the sid install into one
`RUN`, add explicit `nodejs`, and use `--depth 1 --filter=blob:none` for the
grammar clones.

## 1.5 Optional, separate: `.dockerignore`

Worth adding for context-transfer time (the compiled build currently tars ~1.8 GB
of `./build` plus `.git`), but it saves **zero image bytes**, and it must **not**
exclude `.git` — the builder does `COPY ./.git ./.git/` and the build would fail.
Both Dockerfiles share one context, so any ignore file must satisfy the union of
their needs. Treat as a follow-up.

---

# Milestone 2 — `zgornel/julia_app_builder` (~290 MB more)

`build.jl` calls `PackageCompiler.create_app` with only
`precompile_execution_file`, `force=true`, `cpu_target="generic"`. Three unused
levers, in increasing order of risk:

1. **`filter_stdlibs=true`** — drops unused stdlibs from each sysimage. The
   documented caveats are real (a package can use `Random`/`LinearAlgebra` without
   declaring it), and the failure mode is a runtime `MethodError` in a rarely-hit
   linter, so it needs a full functional pass over all linters.
2. **`sysimage_build_args` with `--strip-metadata` / `--strip-ir`** — 10–30% of a
   sysimage. `--strip-ir` removes the IR needed to compile _new_ specializations at
   runtime; with ArgParse and plugin-style dispatch in `src/plugins/**` this is
   high risk. Try `--strip-metadata` alone first.
3. **One shared sysimage** —
   `create_app(..., executables=["datalinter"=>"julia_main", "datalinterserver"=>"server_main"])`.
   This is the largest remaining item (~290 MB compressed, a whole bundle), but it
   requires merging `apps/datalinter` and `apps/datalinterserver` into one Julia
   package (separate `Project.toml`s today, each calling `Base.set_active_project`),
   and the path contract would have to be preserved by making `/datalinterserver` a
   **directory symlink** to the single app root — the one place where
   `/proc/self/exe` symlink resolution works _for_ you rather than against you.

**"Blocked" is softer than it looks.** The external repo enters only via
`RUN git clone …/julia_app_builder` in the builder Dockerfile and
`/julia/bin/julia /julia_app_builder/build.jl /DataLinter` in
`.github/workflows/ci.yml:42`. Adding an in-repo `scripts/build_app.jl` that calls
`create_app` with the desired flags and repointing those two lines unblocks all
three items without touching the external repo. That is a decision about where
build logic should live, not a technical barrier — worth settling before starting M2.

---

# Verification

**Size, before/after** — tag the currently published image as the baseline so the
comparison is honest:

```bash
docker pull ghcr.io/zgornel/datalinter-compiled:latest
docker image inspect -f '{{.Size}}' ghcr.io/zgornel/datalinter-compiled:latest
docker history --format '{{.Size}}\t{{.CreatedBy}}' ghcr.io/zgornel/datalinter-compiled:latest
docker build --no-cache -f docker/debian/Dockerfile.datalinter-compiled.debian -t dl:new .
docker image inspect -f '{{.Size}}' dl:new
docker save dl:new | wc -c     # pushed-bytes proxy
```

**Hardlinks actually survived** (if `nlink = 1`, the COPY got split and the saving
is gone):

```bash
docker run --rm dl:new sh -c 'stat -c "%i %h %n" /datalinter/lib/julia/libLLVM*.so /datalinterserver/lib/julia/libLLVM*.so'
docker run --rm dl:new sh -c 'find / -xdev -type f -links +1 | wc -l'
```

**Warm cache, no compiler:**

```bash
docker run --rm dl:new sh -c 'for g in r python julia c c-sharp javascript; do stat -c "%Y %n" /root/.cache/tree-sitter/lib/$g.so /root/dev/tree-sitter-$g/src/parser.c; done'
docker run --rm dl:new sh -c '! command -v cc && ! command -v gcc && ! command -v make && ! command -v git && echo clean'
docker run --rm dl:new sh -c 'test ! -e /root/.cache/tree-sitter/lock && echo no-lock'
docker run --rm dl:new ldd /usr/bin/tree-sitter
# read-only proof: nothing can be compiled, so success means the cache is genuinely warm
docker run --rm --read-only --tmpfs /tmp dl:new sh -c \
  'printf "x <- 1\n" > /tmp/t.R && tree-sitter parse -q -x --scope source.R /tmp/t.R | head -c 200'
```

Assert exit 0 **and non-empty XML** for each scope — an empty result with exit 0 is
the signature of a parser-directory miss, which is exactly the silent failure mode
ParSitter hides.

**End-to-end, against the documented contract:**

```bash
docker run --rm dl:new /datalinter/bin/datalinter --help
docker run --rm dl:new ls -l /datalinter/config
docker run --rm dl:new /datalinter/bin/datalinter /tmp/test/data/imbalanced_data.csv \
  --code-path /tmp/test/code/r_snippet_imbalanced.r --config-path /tmp/test/test_config.toml
```

Plus a `.py` `--code-path` to exercise a second grammar through ParSitter, and the
server flow from `docs/src/examples.md:214`/`:253` (start `/datalinterserver/bin/datalinterserver`,
POST `/api/lint`, diff the JSON against the current image's output). Re-run the
mount-based invocations at `docs/src/examples.md:104`/`:136`/`:170` to prove
`/_data /_code /_config /output /workspace` still behave.

**Expected harmless regression:** `src/version.jl:12` shells out to `git`, so
removing git changes `printable_version()`. It is already a no-op in the compiled
image (the `try`/`catch` returns empty strings and `pathof(DataLinter)` points at
the build machine's `/DataLinter/src`), but confirm with `--version` before and
after rather than assuming.

**Suggested CI gate:** after building, fail if `docker image inspect -f '{{.Size}}'`
exceeds a committed threshold, so 320 MB of `.git` cannot creep back in.

---

# Critical files

- `docker/debian/Dockerfile.datalinter-compiled.debian` — the main rewrite (3 stages)
- `docker/debian/Dockerfile.datalinter-builder.debian` — layer hygiene, shallow clones
- `.github/workflows/ci.yml` — size gate; `:42` is the M2 build-script hook
- `docs/src/examples.md` — the contract the rewrite must not break
- `~/.julia/packages/ParSitter/vBdbf/src/parse.jl` + `languages/*.toml` — authority
  on the scopes the warmed cache must satisfy
