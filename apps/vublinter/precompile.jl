using vublinter
using VUBLinter

datapath = joinpath(dirname(@__FILE__), "data.csv")
kb = VUBLinter.kb_load("")
data =VUBLinter._generate_workload_data(1000)
ctx = VUBLinter.build_data_context(data);
VUBLinter.lint(ctx, kb; buffer=IOBuffer(), show_passing=false);
VUBLinter.cli_linting_workflow(datapath, "")
#vublinter.julia_main()
