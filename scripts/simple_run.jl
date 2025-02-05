#using Revise
#using Pkg
#Pkg.activate(joinpath(dirname(@__FILE__),".."))  # we assume that this file lies in ./scripts
Base.set_active_project(joinpath(dirname(@__FILE__),"..","Project.toml"))
using Random
using Dates
using Tables
using Revise
using DataLinter

n = 10_000
data = Vector{Any}(Vector{Union{Missing, Float64}}[rand(n) for _ in 1:3])
push!(data, Vector{Union{Missing, Float64}}(ones(n).*1000))
push!(data, [string.(Date(Dates.now())) for _ in 1:n])
push!(data, [(randstring(3)*" "*randstring(2)) for _ in 1:n])
push!(data, [string(rand()) for _ in 1:n])
# Alter data to produce linting output
data[1][1] = -10
data[3][2] = missing
push!(data, rand(["a","b", ["a","b"]], n))
empty_row=10
for col in data
    col[empty_row] = ifelse(typeof(col[empty_row])<:Number, missing, "")
end
duplicates=(10=>11, 12=>13)
for (srow, drow) in duplicates
    for col in data
        col[drow] = col[srow]
    end
end
code = "apply_some_classifier"  # some sample code, will activate only the missing rule

kbpath = joinpath(dirname(@__FILE__), "..", "knowledge", "linting.toml")
kb = DataLinter.kb_load(kbpath)

# First case, print to stdout linting on data
buf =stdout
ctx_no_code = DataLinter.build_data_context(data)
lintout = DataLinter.lint(ctx_no_code, kb; config=nothing);
DataLinter.LinterCore.process_output(lintout; buffer=buf, show_stats=true, show_passing=false)

println("------------")
# Second case, print to buffer (and print the buffer), linting on data+code
buf=stdout; #buf = IOBuffer();
ctx_code = DataLinter.build_data_context(data, code)
@time lintout = DataLinter.lint(ctx_code, kb; config=nothing);
DataLinter.LinterCore.process_output(lintout; buffer=buf, show_stats=true, show_passing=true, show_na=true)
buf isa IOBuffer && DataLinter.OutputInterface.print_buffer(buf);
