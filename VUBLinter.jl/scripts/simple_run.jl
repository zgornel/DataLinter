#using Revise
using Pkg
Pkg.activate(joinpath(dirname(@__FILE__),".."))  # we assume that this file lies in ./scripts

using VUBLinter

data = Vector{Vector{Union{Missing, Float64}}}([rand(3) for _ in 1:5])

# Alter data to produce linting output
data[1][1] = -1
data[5][2] = missing          # add a missing values warning
push!(data, [1.0, 2.0, 3.0])  # add an int as float warning

code = "apply_some_classifier"  # some sample code, will activate only the missing linter

kbpath = expanduser("~/vub/code/vublinter/VUBLinter.jl/knowledge/linting.toml")
kb = VUBLinter.kb_load(kbpath)

# First case, print to stdout linting on data
buf =stdout
ctx_no_code = VUBLinter.build_data_context(data)
lintout = VUBLinter.lint(ctx_no_code, kb, buffer=buf, show_stats=true, show_passing=false);

# Second case, print to buffer (and print the buffer), linting on data+code
buf = IOBuffer();
ctx_code = VUBLinter.build_data_context(data, code)
lintout = VUBLinter.lint(ctx_code, kb, buffer=buf, show_stats=true, show_passing=false);
VUBLinter.OutputInterface.print_buffer(buf)
