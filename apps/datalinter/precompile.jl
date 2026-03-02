using datalinter
using DataLinter

# Use <PROJECT_ROOT>/test/data/data.csv
datapath = joinpath(dirname(@__FILE__), "..", "..", "test", "data", "data.csv")
codepath = joinpath(dirname(@__FILE__), "..", "..", "test", "code", "r_snippet_binomial")
configpath = joinpath(dirname(@__FILE__), "..", "..", "test", "test_config.toml")
kb = DataLinter.kb_load("")
data = DataLinter._generate_workload_data(1000)
ctx = DataLinter.build_data_context(data);
DataLinter.lint(ctx, kb; debug = true);
DataLinter.cli_linting_workflow(
    datapath,
    codepath,
    "",
    configpath;
    buffer = IOBuffer(),
    show_stats = true,
    show_passing = false,
    show_na = false,
    progress = false
)
DataLinter.cli_linting_workflow(
    datapath,
    codepath,
    "",
    configpath;
    buffer = IOBuffer(),
    show_stats = true,
    show_passing = true,
    show_na = true,
    progress = true
)
#datalinter.julia_main()
