#!/bin/sh

# WARNING!
#   This script should be run only inside the ghcr.io/zgornel/vublinter-builder image
#   and not to be run standalone as it requires fixed paths for julia and VUBLinter:
#   - for julia: `/julia/bin/julia`
#   - for VUB Linter: `/VUBLinter`

# Build vublinter
# - result will be in build/vublinter
/julia/bin/julia /VUBLinter/build.jl
