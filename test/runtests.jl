using Test
using DataLinter
using Logging
global_logger(ConsoleLogger(stdout, Logging.Error))  # supress test warnings

include("config.jl")
include("data.jl")
include("linter.jl")
include("rformula.jl")
include("kb.jl")
include("kb_native_linters.jl")
include("version.jl")
