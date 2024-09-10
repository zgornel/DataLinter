using vublinter
using VUBLinter

kb = VUBLinter.kb_load("")
ctx = VUBLinter.build_data_context(VUBLinter._generate_workload_data(1000));
VUBLinter.lint(ctx, kb; buffer=IOBuffer(), show_passing=false);
#vublinter.julia_main()
