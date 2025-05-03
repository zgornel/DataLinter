module DataLintingServer

using Pkg
Pkg.activate(joinpath(dirname(@__FILE__), ".."))  # activate root folder
Pkg.instantiate()
#using Serialization
using Logging
using Sockets
using HTTP
using JSON
using ArgParse
using DataLinter

# Default forecaster port
const SERVER_HTTP_PORT = 10000


# Logging
const LOG_LEVEL = Logging.Debug
global_logger(ConsoleLogger(stdout, LOG_LEVEL))


function get_server_commandline_arguments(args::Vector{String})
	s = ArgParseSettings()
	@add_arg_table! s begin
        "--http-port", "-p"
            help = "HTTP port"
            arg_type = Int
            default = SERVER_HTTP_PORT
        "--http-ip", "-i"
            help = "HTTP IP address"
            default = "127.0.0.1"
        "--model-path"
            help = "Path for the model(s)"
            arg_type = String
            default = ""
        "--log-level"
            help = "logging level"
            default = "debug"
    end
	return parse_args(args,s)
end


########################
# Main module function #
########################
function julia_main()::Cint
    try
        real_main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end


function real_main()
    # Parse command line arguments
    args = get_server_commandline_arguments(ARGS)

    # Logging
    log_levels = Dict("debug" => Logging.Debug,
                      "info" => Logging.Info,
                      "warning" => Logging.Warn,
                      "error" => Logging.Error)
    logger = ConsoleLogger(stdout, get(log_levels, lowercase(args["log-level"]), Logging.Info))
    global_logger(logger)

    # Get IP, port, directory
    http_ip = args["http-ip"]
    http_port = args["http-port"]

    model_path = args["model-path"]
    if isempty(model_path) || !ispath(model_path) || !isfile(model_path)
        @info "Using in-memory linters (model path is missing or wrong)"
    end

    # Start I/O server(s) #
    # ################### #
    linting_server(http_ip, http_port; model_path=model_path)
    return 0
end


function linting_server(addr="127.0.0.1", port=SERVER_HTTP_PORT; model_path="")
    #Checks
    if port <= 0 || port == nothing
        @error "HTTP port $(repr(port)) is not valid. Exiting..."
    end

    addr = try
        IPv4(addr)
        IPv6(addr)
        addr
    catch
        @warn "HTTP IP $addr is not valid, using `localhost`..."
        Sockets.localhost
    end

    # Define REST endpoints to dispatch to "service" functions
    ROUTER = HTTP.Router()
    HTTP.register!(ROUTER, "GET", "/*", noop_req_handler)
    HTTP.register!(ROUTER, "GET", "/api/kill", kill_req_handler)
    HTTP.register!(ROUTER, "POST", "/*", noop_req_handler)
    HTTP.register!(ROUTER, "POST", "/api/lint", linting_handler_wrapper(model_path))

    # Start serving requests
    @info "• Data linting server online @$addr:$port..."
    HTTP.serve(Sockets.IPv4(addr), port, readtimeout=0) do http_req::HTTP.Request
        handler_output = try
            ROUTER(http_req)
        catch e
            @debug "Error handling HTTP request.\n$e"
            -1  # will be visible in HTTP headers, "Status"=>"ERROR"
        end
        #TODO(Corneliu): Differentiate between types of errors
        if handler_output === nothing
            # An unsupported endpoint was called
            return HTTP.Response(501, ["Access-Control-Allow-Origin"=>"*", "Status"=>"OK"], body="")
        elseif handler_output isa String
            # All OK, send request to search server and get response
            return HTTP.Response(200, ["Access-Control-Allow-Origin"=>"*", "Status"=>"OK"], body=handler_output)
        elseif handler_output isa Int
            _status = ifelse(handler_output == 0, "OK", "ERROR")
            return HTTP.Response(200, ["Access-Control-Allow-Origin"=>"*", "Status"=>_status], body="")
        else
            return HTTP.Response(400, ["Access-Control-Allow-Origin"=>"*"], body="")  # failsafe (not used)
        end
    end
end


noop_req_handler(req::HTTP.Request) = nothing


kill_req_handler(req::HTTP.Request) = begin
    @info "Kill request received. Exiting in 1s..."
    @async begin
        sleep(1)  # some time to send back HTTP response
        exit()
    end
    return 0
end


linting_handler_wrapper(model_path) = (req::HTTP.Request)->begin
    @debug "HTTP request $(req.target) received."
    # Process HTTP linting request
    _request = JSON.parse(IOBuffer(HTTP.payload(req)))
    model = nothing  # by default, use in-memory
    model = if !isempty(model_path)
        open(model_path) do io
            try
                deserialize(io)
            catch e
                @warn "Model deserialization error: $e"
            end
        end
    end
    model !== nothing && @debug "Model loaded @$_model_path"
   
    #TODO: Handle errors here
    ctx = _request["linter_input"]["context"]
    data = ctx["data"]
    for dv in data
        dv[isnothing.(dv)] .= missing
    end
    code = ctx["code"]
    kbpath = expanduser(_request["linter_input"]["kbpath"])
    kb = DataLinter.kb_load(kbpath)
    show_passing = get(_request["linter_input"]["options"], "show_passing", false)
    show_stats = get(_request["linter_input"]["options"], "show_stats", false)
    show_na = get(_request["linter_input"]["options"], "show_stats", false)
    try
        buffer = IOBuffer();
        ctx_code = DataLinter.build_data_context(data, code)
        lintout = DataLinter.lint(ctx_code, kb);
        process_output(lintout; buffer, show_passing, show_stats, show_na)
        string_buf = read(seekstart(buffer), String)
        return JSON.json("linting_output" => string_buf)
    catch e
        @warn "Linting error: $e"
        return nothing
    end
end


##############
# Run client #
##############
if abspath(PROGRAM_FILE) == @__FILE__
    real_main()
end


end  # module

