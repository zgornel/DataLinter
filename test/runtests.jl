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
include("version.jl")

# csv and r
include("data_csv.jl")
include("kb_native_linters_csv_r.jl")

# arrow and r
include("data_arrow.jl")
include("kb_native_linters_arrow_r.jl")

# parquet and r
include("data_parquet.jl")
include("kb_native_linters_parquet_r.jl")
