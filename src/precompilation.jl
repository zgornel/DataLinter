using Dates
using Random
using CSV
using Tables

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
    return Tables.Columns(Dict(Symbol("x$i")=>data[i] for i in 1:length(data)))
end


# First case, print to stdout linting on data
function _workload(data, kb)
    ctx_no_code = DataLinter.build_data_context(data)
    lintout = DataLinter.lint(ctx_no_code, kb; debug=true)
    return nothing
end


#TODO: Improve performance when using scripts:
# https://timholy.github.io/SnoopCompile.jl/stable/tutorials/invalidations/

using PrecompileTools: @setup_workload, @compile_workload
@setup_workload begin
    @compile_workload begin
        using CSV
        using Tables
        using StatsBase
        # Workload 1
        kbpath = abspath(joinpath(dirname(@__FILE__), "..", "knowledge", "linting.toml"))
        kb = DataLinter.kb_load(kbpath)
        ctx = DataLinter.build_data_context(_generate_workload_data());
        DataLinter.lint(ctx, kb; debug=false, progress=true)
        DataLinter.lint(ctx, kb; debug=false, progress=false)
    end
end
