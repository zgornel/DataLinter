using Pkg
const PROJECT_PATH = joinpath(abspath(dirname(@__FILE__)), "..")
Pkg.activate(joinpath(PROJECT_PATH))  # we assume that this file lies in ./scripts
using DelimitedFiles
using HTTP
using JSON


data_path = joinpath(PROJECT_PATH, "data", "imbalanced_data.csv")
code_path = joinpath(PROJECT_PATH, "data", "r_snippet.r")

_data, _header = readdlm(data_path, ',', header = true)
data = Dict(h => col for (h, col) in zip(_header, collect(eachcol(_data))))

linter_input = Dict(
    "context" => Dict(
        "data" => data,
        "code" => read(code_path, String)
    ),
    "options" => Dict(
        "show_stats" => true,
        "show_passing" => false,
        "show_na" => false
    )
)
request = Dict("linter_input" => linter_input)

# Send to server
reply = try
    HTTP.post("http://localhost:10000/api/lint", Dict(), JSON.json(request))
catch e
    @warn "Something went wrong with request processing $e"
    nothing
end
@show reply
if reply !== nothing
    output = JSON.parse(IOBuffer(reply.body))
    @info output["linting_output"]
end
