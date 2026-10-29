# Docker image size reduction — task tracker

Target: `ghcr.io/zgornel/datalinter-compiled`. Design, evidence and verification
procedures are in [docs/docker-image-reduce-size-TECH-DESIGN.md](docs/docker-image-reduce-size-TECH-DESIGN.md).

**Baseline: 1217.67 MB compressed, 22 layers** (measured from the published
manifest). Sizes below are **compressed MB**, i.e. pull size, the same metric as
the baseline. A negative number means the task *adds* bytes.

| Milestone | Task | Description | Status | Size saved (MB) |
|---|---|---|---|---|
| 1 | 1.1 | Grammar clones `--depth 1 --filter=blob:none`, then prune each to `tree-sitter.json` + `src/{parser.c,scanner.c,grammar.json}`. Removes ~320 MB of `.git` history | done | **317** (measured) |
| 1 | 1.2 | Multi-stage split: `gcc g++ make git wget curl jq tar gzip dpkg` confined to the `prep` stage, final stage gets `ca-certificates libxml2 libgcc-s1` only | done | **135** (measured) |
| 1 | 1.3 | Copy the `tree-sitter` CLI binary from `prep` instead of installing from Sid in the final image; drop `libtree-sitter0.26` (CLI links it statically) | done | **102** (measured) |
| 1 | 1.4 | Layer hygiene: single `apt` layer with `--no-install-recommends`, lists cleaned, Sid repo added-used-dropped in one layer | done | **33.7** (measured) |
| 1 | 1.5 | Pre-compile the six parser `.so` into the cache at build time — the enabler that makes 1.2 safe. Also removes a multi-second recompile from first parse in every new container | done | **−1.8** (adds) |
| 1 | 1.6 | Pin parser/source mtimes and keep the lock directory out, so the warm cache cannot be invalidated at runtime | done | 0 |
| 1 | 1.7 | Build-time gate in the final stage: no compiler present, every scope parses to non-empty output, or the build fails | done | 0 |
| 1 | 1.8 | Delete the four dead priming `RUN`s (empty layers that ran before tree-sitter existed; one backgrounded into a dying layer) | done | 0 |
| 1 | 1.9 | Hardlink-dedup the two app bundles in the `apps` stage, copied out with a single `COPY --from` | done | **100–150** (est., see 1.11) |
| 1 | 1.10 | Builder-image hygiene: Julia download/unpack/delete in one layer (the ~290 MB tarball was staying resident), one Sid layer, explicit `nodejs`, shallow clones, parsers pre-compiled | done | 0 (not pushed; CI disk/time only) |
| 1 | 1.11 | CI step reporting image size and layer breakdown; fails if no hardlinks survived | done | 0 |
| 1 | A1 | Confirm the real dedup ratio from the first CI run. If far below ~100 MB, the bundles share less than expected and 2.4 becomes the main lever | to do | 0 (measurement) |
| 1 | A2 | Add a numeric size ceiling to the CI step, once 1.11 reports the post-change size | to do | 0 (regression guard) |
| 1 | A3 | Optional: truncate `parser.c` after warming (the loader only stats it). 69 MB uncompressed but only ~10 MB compressed — generated tables compress ~20:1 | to do | ~10 (est.) |
| 1 | A4 | `.gitattributes` needs `git add -f` (this repo's `.gitignore` has a `.*` rule). Not critical — `scopes.txt` is read through `tr -d '\r'` | to do | 0 |
| 1 | A5 | Optional `.dockerignore` for context-transfer time. Must **not** exclude `.git` — the builder does `COPY ./.git ./.git/` | to do | 0 (build time only) |
| 1 | A6 | Build-time language selection (`DATALINTER_LANGUAGES`) — implemented, verified, then reverted on request. Notes for rebuilding it are in the design doc | reverted | 0 (3.7 est. if restored) |
| 1 | A7 | Fix `docs/src/examples.md:36`: documents `/datalinterserver/datalinterserver`, binary is at `/datalinterserver/bin/datalinterserver`. Pre-existing, unrelated | to do | 0 |
| 1 | A8 | Confirm `--version` output before/after removing `git` (`src/version.jl` shells out to it; already a no-op in the compiled image) | to do | 0 |
| 2 | 2.1 | **B0 — decide where build logic lives.** An in-repo `scripts/build_app.jl` calling `create_app`, with the builder Dockerfile's `git clone` and `ci.yml:42` repointed, unblocks 2.2–2.4 without touching `zgornel/julia_app_builder`. Shapes everything after it | to do | 0 (decision) |
| 2 | 2.2 | `filter_stdlibs=true` in `create_app`. Needs a functional pass over all linters; failure mode is a runtime `MethodError` in a rarely-hit rule | to do | unknown |
| 2 | 2.3 | `sysimage_build_args`: `--strip-metadata` first, `--strip-ir` only if validated (it removes IR needed for new specializations; risky with ArgParse and plugin dispatch) | to do | 10–30% of each sysimage (est.) |
| 2 | 2.4 | One shared sysimage for both executables (`executables=["datalinter"=>…, "datalinterserver"=>…]`). Requires merging the two app projects and a `/datalinterserver` directory symlink to preserve documented paths | to do | ~290 (est.) |

## Totals

| | Compressed MB |
|---|---|
| Baseline, published | 1217.67 |
| Milestone 1, measured (tasks 1.1–1.8) | **−586.6** |
| Milestone 1, pending measurement (task 1.9) | −100 to −150 (est.) |
| **Projected after Milestone 1** | **~480–530 (−56% to −61%)** |
| Milestone 2, if fully done (2.2–2.4) | −290 and up (est.) |

The measured figure is solid: everything the new image ships *except* the two app
bundles was measured at **39.4 MB compressed**, against **625.96 MB** for the same
layers in the published image. Task 1.9 is the only Milestone 1 item whose saving
is unmeasured, because `./build/` exists only after the builder runs in CI.

## Status legend

- **done** — implemented and verified by building. See the design doc's §5.1 for
  the verification matrix, including the read-only-rootfs proof that the parser
  cache is genuinely warm and the two negative tests.
- **to do** — not started.
- **reverted** — implemented and verified, then removed on request.

Nothing in this tracker has been committed yet.
