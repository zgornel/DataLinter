#!/bin/julia
module datalinterw

# The actual entrypoint is apps/datalinter/src/datalinter.jl
const DATALINTERPATH = abspath(joinpath(@__DIR__, "apps", "datalinter", "src", "datalinter.jl"))
include(DATALINTERPATH)  # adds module datalinter

import Pkg, UUIDs
prj = Pkg.project()
if prj.name != "DataLinter" || prj.uuid != UUIDs.UUID("7795ac26-99bd-44b7-aa9b-4d57ee2553a8")
    @warn "Something is off, datalinter should have already activated the project environment."
    Pkg.activate(@__DIR__)  # activates current directory (DataLinter project directory) only if not already activated by datalinter
    Pkg.instantiate()
end

main_script_file = abspath(PROGRAM_FILE)

if occursin("debugger", main_script_file) || main_script_file == @__FILE__
    datalinter.real_main()
end

end  # module
