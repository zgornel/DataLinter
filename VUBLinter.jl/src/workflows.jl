using Dates
using Random
using DataFrames
using CSV

function _generate_workload_data(n=100)
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
    return data
end


# First case, print to stdout linting on data
function _workload_1(data, kb)
    ctx_no_code = VUBLinter.build_data_context(data)
    lintout = VUBLinter.lint(ctx_no_code, kb, buffer=IOBuffer(), show_stats=true, show_passing=true);
    return nothing
end

# Second case, print to buffer (and print the buffer), linting on data+code
function _workload_2(data, kb, code)
    ctx_code = VUBLinter.build_data_context(data, code)
    lintout = VUBLinter.lint(ctx_code, kb, buffer=IOBuffer(), show_stats=true, show_passing=true, show_na=true);
    return nothing
end

function _csv_workload(csvpath, kb, code)
    ctx_code = VUBLinter.build_data_context(CSV.read(csvpath, DataFrame), code)
    lintout = VUBLinter.lint(ctx_code, kb, buffer=IOBuffer(), show_stats=true, show_passing=true, show_na=true);
    return nothing
end

function cli_linting_workflow(filepath, kbpath, args...)
    kb = VUBLinter.kb_load(kbpath)
    buf =stdout
    ctx = VUBLinter.DataInterface.build_data_context(filepath)
    lintout = lint(ctx, kb, buffer=buf, show_stats=true, show_passing=false, show_na=false);
end

# Run workloads
kb = VUBLinter.kb_load(joinpath(dirname(@__FILE__), "..", "knowledge", "linting.toml"))
data = _generate_workload_data()
code = "some_code_w_classifier"
_workload_1(data, kb)
_workload_2(data, kb, code)

# Disassebmbed cli_linting_workflow
kb = VUBLinter.kb_load(abspath(joinpath(dirname(@__FILE__), "..", "knowledge", "linting.toml")))
ctx = VUBLinter.DataInterface.build_data_context(abspath(joinpath(dirname(@__FILE__), "..", "..", "data", "churn_mini.csv")))
lintout = lint(ctx, kb, buffer=IOBuffer(), show_stats=true, show_passing=false, show_na=false);
