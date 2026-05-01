#!/usr/bin/env -S julia --startup-file=no
#=
datalinter.jl

Portable cross-platform Julia-based datalinter Docker execution

This script:
- Runs the datalinter from the Docker image with a data argument
- Forwards ALL additional command-line arguments (extra flags) to the inner
  /datalinter/bin/datalinter binary inside the Docker container.
- Uses only Base Julia (no extra packages).
- Handles paths correctly on Windows, Linux, and macOS.

Usage
─────
• Unix-like (Linux/macOS/Git Bash/WSL):
    ./datalinter.jl path/to/yourfile.csv [extra flags...]

• Windows (PowerShell or cmd):
    julia --startup-file=no datalinter.jl "C:\path\to\yourfile.csv" [extra flags...]

Examples
────────
./datalinter.jl mydata.csv --log-level debug
./datalinter.jl data.csv --progress --timed
./datalinter.jl report.csv --print-exceptions --config-path /datalinter/config/custom.toml
=#

# Minimal argument check
if length(ARGS) < 1 || isempty(ARGS[1])
    println("First argument i.e. csv file doesn’t exist or is empty.")
    exit(1)
end

input_arg = ARGS[1]

# Compute directory and filename portably (works with Windows paths, spaces, etc.)
dir  = dirname(abspath(input_arg))
file = basename(input_arg)

# Build Docker command
docker_cmd = Cmd([
    "docker",
    "run",
    "-it",
    "--rm",
    "--volume=$(dir):/tmp",
    "ghcr.io/zgornel/datalinter-compiled:latest",
    "/datalinter/bin/datalinter",
    "/tmp/$(file)",
    "--config-path",
    "/datalinter/config/default.toml",
    "--progress",
    "--timed",
    "--print-exceptions",
    "--log-level",
    "error",
    # Forward all extra flags passed by the user
    ARGS[2:end]...
])

# Execute (Docker output and exit code are forwarded exactly)
run(docker_cmd)
