using Test
using DataLinter
using Logging
global_logger(ConsoleLogger(stdout, Logging.Error))  # supress test warnings

#TODO: Implement tests for the other modules of DataLinter
include("config.jl")
