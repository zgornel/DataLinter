#!/usr/bin/env -S julia --startup-file=no --project=@runic

#=
runrunic.jl

Portable cross-platform replacement for runrunic.sh (dev-only Runic linter runner).

This script:
1. Ensures the Runic package is installed in the @runic Julia environment.
2. Runs Runic.main() 

Usage
─────
• Unix-like (Linux/macOS/Git Bash/WSL):
    ./runrunic.jl

• Windows (PowerShell or cmd):
    julia --startup-file=no --project=@runic runrunic.jl

You can also pass custom Runic arguments:
    julia --startup-file=no --project=@runic runrunic.jl --help
=#

using Pkg

# Install Runic into the @runic environment (idempotent — safe to run every time)
Pkg.add("Runic")

using Runic

# Default arguments exactly as in the original runrunic.sh
# (users can override by passing their own arguments)
const DEFAULT_ARGS = ["--inplace", "src/", "apps/", "scripts/", "test/", "knowledge/"]
runic_args = isempty(ARGS) ? DEFAULT_ARGS : ARGS

# Optional friendly message (remove if you prefer zero extra output)
println("Running Runic linter (in-place mode) on: src/ apps/ scripts/ test/ knowledge/")

# Execute Runic and forward its exit code
exit(Runic.main(runic_args))
