using Pkg
Pkg.add("Documenter")

using Documenter
using VUBLinter

# Make src directory available
push!(LOAD_PATH,"../src/")

# Make documentation
makedocs(
    #modules = [VUBLinter],
    format = Documenter.HTML(),
    sitename = "VUB Data Linter",
    authors = "Corneliu Cofaru, Vrije Universiteit Brussel",
    clean = true,
    debug = true,
    pages = [
        "Introduction" => "index.md",
        "Usage examples" => "examples.md",
        "API Reference" => "api.md"
    ],
    repo = "github.com:zgornel/VUBLinter.git",
)

# Deploy documentation
deploydocs(
    #remotes=nothing,
    repo = "github.com/zgornel/VUBLinter.git",
    target = "build",
    deps = nothing,
    make = nothing
)
