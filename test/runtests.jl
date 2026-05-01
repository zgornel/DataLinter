using Test
using Logging
using DataLinter
using Tables

global_logger(ConsoleLogger(stdout, Logging.Error))  # supress test warnings

include("config.jl")
include("data.jl")
include("linter.jl")
include("rformula.jl")
include("kb.jl")
include("output.jl")
include("kb_native_linters.jl")
include("version.jl")
