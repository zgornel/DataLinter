using datalinterserver
using DelimitedFiles
using HTTP
using JSON
using DataLinter

TEST_PATH = abspath(joinpath(dirname(@__FILE__), "..", "..", "test"))
configpath = joinpath(TEST_PATH, "test_config.toml")
DATA_PATHS = [
    joinpath(TEST_PATH, "data", "correlated_data.arrow"),
    joinpath(TEST_PATH, "data", "correlated_data.parquet"),
]
csvdatapath = joinpath(TEST_PATH, "data", "correlated_data.csv")
codepath = joinpath(dirname(@__FILE__), "..", "..", "test", "code", "r_snippet_imbalanced.r")
configpath = joinpath(dirname(@__FILE__), "..", "..", "test", "test_config.toml")

# Start server
IP = "127.0.0.1"
PORT = 10_000
config = DataLinter.Configuration.load_config(configpath)
@async datalinterserver.linting_server(IP, PORT; config)

# Client part
LINTER_INPUTS = [
    Dict(
        "context" => Dict(
            "data" => read(csvdatapath, String),
            "data_type" => "dataset",
            "linters" => ["all"],
            "data_delim" => ",",
            "data_header" => true,
            "code" => read(codepath, String)
        ),
        "options" => Dict(
            "output_type" => "text",
            "show_stats" => true,
            "show_passing" => false,
            "show_na" => false
        )
    ),
    Dict(
        "context" => Dict(
            "data" => read(csvdatapath, String),
            "data_type" => "dataset",
            "linters" => ["all"],
            "data_delim" => ",",
            "data_header" => true,
            "code" => read(codepath, String)
        ),
        "options" => Dict(
            "output_type" => "json",
            "show_stats" => true,
            "show_passing" => true,
            "show_na" => true
        )
    ),
    [
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
                "output_type" => output_type,
                "show_stats" => true,
                "show_passing" => true,
                "show_na" => true
            )
        )
        for datapath in DATA_PATHS for output_type in ["text","json"]
    ]...
]

for linter_input in LINTER_INPUTS
    request = Dict("linter_input" => linter_input)

    # Send to server
    reply = try
        HTTP.post("http://$IP:$PORT/api/lint", Dict(), JSON.json(request))
    catch e
        @warn "Something went wrong with request processing $e"
        nothing
    end
    if reply !== nothing
        output = JSON.parse(IOBuffer(reply.body))
        @info "Reply received ok, size of $(Base.summarysize(output))"
    end
end

HTTP.get("http://$IP:$PORT/api/kill", Dict(), JSON.json(Dict()))
