using datalinterserver
using DelimitedFiles
using HTTP
using JSON

# Use <PROJECT_ROOT>/test/data/data.csv
data_path = joinpath(dirname(@__FILE__), "..", "..", "test", "data", "imbalanced_data.csv")
code_path = joinpath(dirname(@__FILE__), "..", "..", "test", "code", "r_snippet.r")
config_path = joinpath(dirname(@__FILE__), "..", "..", "config", "r_glmmTMB_imbalanced_data.toml")

# Start server
IP = "127.0.0.1"
PORT = 10_000
@async datalinterserver.linting_server(IP, PORT; config_path)

# Client part
_data, _header = readdlm(data_path, ',', header=true)
data = Dict(h=>col for (h,col) in zip(_header, collect(eachcol(_data))))

linter_input = Dict("context" => Dict("data"=>data,
                                      "code"=>read(code_path, String)),
                    "options" =>Dict("show_stats"=>true,
                                     "show_passing"=>false,
                                     "show_na"=>false))
request = Dict("linter_input"=>linter_input)

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

HTTP.get("http://$IP:$PORT/api/kill", Dict(), JSON.json(request))
