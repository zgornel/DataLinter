# Script should be ran from project root with:
# `$julia --project scripts/client_example.jl /path/to/data.csv /path/to/code.r`
#
using Pkg
using DelimitedFiles
using HTTP
using JSON

function _load_data(data_path)
    return read(data_path, String)
end


function client_main(args)
    data_path, code_path = args
    data = _load_data(data_path)
    r_code = read(code_path, String)
    #println("--- Code:")
    #println(r_code)

    _data_path = abspath(expanduser(data_path))
    linter_input = Dict(
        "context" => Dict(
            "data" => data,             # can be the data or a path to it
            "data_type" => "dataset",   # "dataset" or "filepath"
            #"data" => data_path,
            #"data_type" => "filepath",
            "linters" => ["all"],       # which linters to use: "google", "r", "experimental" or "all"
            "data_delim" => ",",        # csv delimiter
            "data_header" => true,      # header
            "code" => r_code            # code
        ),
        "options" => Dict(
            "show_stats" => true,       # whether to print statistics
            "show_passing" => false,    # show linters that passed (no issues)
            "show_na" => false          # show linters that were not applicable
        )
    )
    request = Dict("linter_input" => linter_input)
    #println("--- Request:")
    #println(request)

    # Send to server
    reply = try
        HTTP.post("http://0.0.0.0:10000/api/lint", Dict(), JSON.json(request))
    catch e
        @warn "Something went wrong with request processing $e"
        nothing
    end
    return if reply !== nothing
        output = JSON.parse(IOBuffer(reply.body))
        println("--- Linting output (HTTP Status: $(reply.status)):")
        println(output["linting_output"])
    end
end

client_main(ARGS)
