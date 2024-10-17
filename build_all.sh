#!/bin/sh

# WARNING!
#   This script should be run only inside the ghcr.io/zgornel/datalinter-builder image
#   and not to be run standalone as it requires fixed paths for julia and DataLinter:
#   - for julia: `/julia/bin/julia`
#   - for DataLinter: `/DataLinter`

# Build datalinter
# - result will be in build/datalinter
/julia/bin/julia /DataLinter/build.jl
