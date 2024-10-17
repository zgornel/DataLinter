using datalinter
using DataLinter

# Use <PROJECT_ROOT>/test/data/data.csv
datapath = joinpath(dirname(@__FILE__), "..", "..", "test", "data", "data.csv")
kb = DataLinter.kb_load("")
data =DataLinter._generate_workload_data(1000)
ctx = DataLinter.build_data_context(data);
DataLinter.lint(ctx, kb; buffer=IOBuffer(), show_passing=false);
DataLinter.cli_linting_workflow(datapath, ""; buffer=IOBuffer())
#datalinter.julia_main()
