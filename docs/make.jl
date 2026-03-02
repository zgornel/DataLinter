using Pkg
Pkg.add("Documenter")
Pkg.add("DocumenterMermaid")

using Documenter
using DocumenterMermaid
using DataLinter

# Make src directory available
push!(LOAD_PATH,"../src/")

# Make documentation
makedocs(
    #modules = [DataLinter],
    format = Documenter.HTML(),
    sitename = "DataLinter",
    authors = "Corneliu Cofaru",
    clean = true,
    debug = true,
    pages = [
        "Introduction" => "index.md",
        "Usage examples" => "examples.md",
        "Linters and configuration" => "linters_config.md",
        "API Reference" => "api.md"
    ],
    repo = "github.com:zgornel/DataLinter.git",
)

# Deploy documentation
deploydocs(
    #remotes=nothing,
    repo = "github.com/zgornel/DataLinter.git",
    target = "build",
    deps = nothing,
    make = nothing
)
