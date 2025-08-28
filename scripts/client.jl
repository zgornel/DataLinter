# Script should be ran from project root with:
# `$julia --project scripts/client_example.jl /path/to/data.csv /path/to/code.r`
#
using Pkg
using DelimitedFiles
using HTTP
using JSON

function _load_data(data_path)
    _data, _header = readdlm(data_path, ',', header = true)
    data = Dict(h => col for (h, col) in zip(_header, collect(eachcol(_data))))
end


function client_main(args)
    data_path, code_path = args
    data = _load_data(data_path)
    r_code = read(code_path, String)
    println("--- Code:")
    println(r_code)

    #@show _code
    #@show data
    linter_input = Dict(
        "context" => Dict(
            "data" => data,
            "code" => r_code
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
        HTTP.post("http://0.0.0.0:10000/api/lint", Dict(), JSON.json(request))
    catch e
        @warn "Something went wrong with request processing $e"
        nothing
    end
    if reply !== nothing
        output = JSON.parse(IOBuffer(reply.body))
        println("--- Linting output (HTTP Status: $(reply.status)):")
        println(output["linting_output"])
    end
end

client_main(ARGS)
