using Dates
using Random

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

code = "apply_some_classifier"  # some sample code, will activate only the missing rule
kbpath = expanduser("~/vub/code/vublinter/VUBLinter.jl/knowledge/linting.toml")
kb = VUBLinter.kb_load(kbpath)

# First case, print to stdout linting on data
function _workload_1(data, kb)
    ctx_no_code = VUBLinter.build_data_context(data)
    lintout = VUBLinter.lint(ctx_no_code, kb, buffer=IOBuffer(), show_stats=true, show_passing=false);
    return nothing
end

# Second case, print to buffer (and print the buffer), linting on data+code
function _workload_2(data, kb, code)
    ctx_code = VUBLinter.build_data_context(data, code)
    lintout = VUBLinter.lint(ctx_code, kb, buffer=IOBuffer(), show_stats=true, show_passing=false, show_na=false);
    return nothing
end


# Run workloads
_workload_1(_generate_workload_data(),
            VUBLinter.kb_load(joinpath(dirname(@__FILE__), "..", "knowledge", "linting.toml"))
            )

_workload_2(_generate_workload_data(),
            VUBLinter.kb_load(joinpath(dirname(@__FILE__), "..", "knowledge", "linting.toml")),
            "apply_some_classifier"  # some random code
            )
