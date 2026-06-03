#using Revise
using Pkg
const PROJECT_PATH = joinpath(abspath(dirname(@__FILE__)), "..")
Pkg.activate(joinpath(PROJECT_PATH))  # we assume that this file lies in ./scripts
#Base.set_active_project(PROJECT_PATH, "Project.toml")
using Logging; global_logger(ConsoleLogger(Logging.Debug))
using Random
using Dates
using CSV
using DataLinter
using ParSitter

kb = DataLinter.kb_load(joinpath(PROJECT_PATH, "knowledge", "linting.toml"))
filepath = nothing
code_path = joinpath(PROJECT_PATH, "test", "code", "r_snippet_imbalanced.r")

config_path = joinpath(PROJECT_PATH, "test", "test_code_only_dummy_linter.toml")
config = DataLinter.LinterCore.load_config(config_path)

ctx = DataLinter.DataInterface.build_data_context(filepath, read(code_path, String))

@time out = DataLinter.lint(ctx, kb; config = config);
DataLinter.process_output(out; show_stats = true, show_na = true, show_passing = true)
