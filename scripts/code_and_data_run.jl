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
filepath = joinpath(PROJECT_PATH, "test", "data", "imbalanced_data.csv")
code_path = joinpath(PROJECT_PATH, "test", "code", "r_snippet_imbalanced.r")

config_path = joinpath(PROJECT_PATH, "config", "r_modelling_config.toml")
config = DataLinter.LinterCore.load_config(config_path)

ctx = DataLinter.DataInterface.build_data_context(filepath, read(code_path, String))

@time out = DataLinter.lint(ctx, kb; config = config);
DataLinter.process_output(out; show_stats = true, show_na=true, show_passing=true)
@info "Score: $(DataLinter.OutputInterface.score(out; normalize = true))"

# For debugging linting contexts
ll = DataLinter.LinterCore.build_linters(ctx, kb)[end]
code_ctx = DataLinter.LinterCore.build_linting_context(read(code_path, String), ll)
rctx = DataLinter.LinterCore.reconcile_contexts(code_ctx, DataLinter.LinterCore.build_linting_context(config));
@show code_ctx
