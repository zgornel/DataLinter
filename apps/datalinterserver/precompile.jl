using datalinterserver
using DelimitedFiles
using HTTP
using JSON

# Use <PROJECT_ROOT>/test/data/data.csv
datapath = joinpath(dirname(@__FILE__), "..", "..", "test", "data", "imbalanced_data.csv")
codepath = joinpath(dirname(@__FILE__), "..", "..", "test", "code", "r_snippet_imbalanced.r")
configpath = joinpath(dirname(@__FILE__), "..", "..", "test", "test_config.toml")

# Start server
IP = "127.0.0.1"
PORT = 10_000
@async datalinterserver.linting_server(IP, PORT; configpath)

# Client part
LINTER_INPUTS = [
    Dict(
        "context" => Dict(
            "data" => read(datapath, String),
            "data_type" => "dataset",
            "linters" => ["all"],
            "data_delim" => ",",
            "data_header" => true,
            "code" => read(codepath, String)
        ),
        "options" => Dict(
            "show_stats" => true,
            "show_passing" => false,
            "show_na" => false
        )
    ),

    Dict(
        "context" => Dict(
            "data" => datapath,
            "data_type" => "filepath",
            "linters" => ["all"],
            "data_delim" => ",",
            "data_header" => true,
            "code" => read(codepath, String)
        ),
        "options" => Dict(
            "show_stats" => true,
            "show_passing" => false,
            "show_na" => false
        )
    ),
]

request = Dict()
for linter_input in LINTER_INPUTS
    request = Dict("linter_input" => linter_input)

    # Send to server
    reply = try
        HTTP.post("http://$IP:$PORT/api/lint", Dict(), JSON.json(request))
    catch e
        @warn "Something went wrong with request processing $e"
        nothing
    end
    @show reply
    if reply !== nothing
        output = JSON.parse(IOBuffer(reply.body))
        @info output["linting_output"]
    end
end
HTTP.get("http://$IP:$PORT/api/kill", Dict(), JSON.json(request))
