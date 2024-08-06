module VUBLinter

using Reexport
#=
 The architecture for VUBLinter
 ------------------------------

 * Dataflow diagram:
                                  .---------------.
     KNOWLEDGE ------------------>|  KB INTERFACE |
                                  `---------------'
                                          ^
                                         (3)
                                          v
             .----------------.        .--------.        .-----------------.
     DATA -> | DATA INTERFACE | -(1)-> | LINTER | -(4)-> |OUTPUT INTERFACE | -(5)-> OUTPUT
             `----------------'        `--------.        `-----------------'
                  ^                       ^                      ^
     CONFIG ------'------(2)--------------'----------------------'

=#


include("linter.jl")  # linter core
include("data.jl")    # data interface
include("output.jl")  # output interface
include("kb.jl")      # kb interface

end # module VUBLinter
