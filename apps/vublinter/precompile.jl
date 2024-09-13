using vublinter
using VUBLinter

kb = VUBLinter.kb_load("")
data =VUBLinter._generate_workload_data(1000)
ctx = VUBLinter.build_data_context(data);
VUBLinter.lint(ctx, kb; buffer=IOBuffer(), show_passing=false);
#vublinter.julia_main()
