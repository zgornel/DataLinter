module vublinterw

# The actual entrypoint is apps/vublinter/src/vublinter.jl
const VUBLINTERPATH = abspath(joinpath(@__DIR__, "apps", "vublinter", "src", "vublinter.jl"))
include(VUBLINTERPATH)  # adds module vublinter

import Pkg, UUIDs
prj = Pkg.project()
if prj.name != "VUBLinter" || prj.uuid != UUIDs.UUID("7795ac26-99bd-44b7-aa9b-4d57ee2553a8")
    @warn "Something is off, vublinter should have already activated the project environment."
    Pkg.activate(@__DIR__)  # activates current directory (VUBLinter project directory) only if not already activated by vublinter
    Pkg.instantiate()
end

main_script_file = abspath(PROGRAM_FILE)

if occursin("debugger", main_script_file) || main_script_file == @__FILE__
    vublinter.real_main()
end

end  # module
