# Patches for external repositories

## `julia_app_builder-strip-metadata.patch`

Applies to [`zgornel/julia_app_builder`](https://github.com/zgornel/julia_app_builder),
which owns the `PackageCompiler.create_app` call that produces the two app bundles
in `build/`. This repository clones it at builder-image build time
(`docker/debian/Dockerfile.datalinter-builder.debian`) and runs it from
`.github/workflows/ci.yml`.

The patch adds `sysimage_build_args = \`--strip-metadata\`` to the build context and
forwards it to `create_app`. It drops docstrings, source-location and other
reflection metadata from the sysimage; it does **not** remove compiled code or IR.

Measured effect (see `../docs/docker-image-reduce-size-TECH-DESIGN.md` §5.4):

- `sys.so` 749.2 → 625.5 MB per bundle (−16.5%)
- both bundles together, hardlink-deduped: 472.7 → 413.0 MB compressed (−59.7 MB)
- output byte-identical to the unpatched build across data linting, R and Python
  code linting, both `--help` outputs, and runtime keyword-argument discovery

Verified against commit `58a93c8` of that repo.

To apply:

```bash
git clone https://github.com/zgornel/julia_app_builder
cd julia_app_builder
git apply /path/to/julia_app_builder-strip-metadata.patch
```

Until it is merged upstream, the published image is built from the unpatched
`build.jl`, so the 59.7 MB is not yet in the shipped artifact.

### Also worth fixing while in that file (not in this patch)

`build_targets = filter(!isdir, readdir(apps_path))` is meant to exclude
directories, but `isdir` resolves the bare names against the process's current
working directory rather than `apps_path`, so both app directories pass a filter
designed to reject them. It works only because the relative paths do not resolve.
Left out to keep the diff minimal.
