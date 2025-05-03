using Pkg
Pkg.activate(joinpath(dirname(@__FILE__), ".."))  # activate root folder
using HTTP
using JSON

data = Vector{Vector{Union{Missing, Float64}}}([rand(3) for _ in 1:5])
# Alter data to produce linting output
data[1][1] = -1
data[5][2] = missing

kbpath = joinpath(dirname(@__FILE__), "..", "knowledge/linting.toml")
linter_input = Dict("context" => Dict("data"=>data,
                                      "code"=>"classifier"),
                    "kbpath" => kbpath,
                    "options" =>Dict("show_stats"=>true,
                                     "show_passing"=>false,
                                     "show_na"=>false))
request = Dict("linter_input"=>linter_input)

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
