module datalinterserver

using Pkg
project_root_path = abspath(joinpath(splitpath(@__FILE__)[1:(end - 4)]...))
Base.set_active_project(abspath(joinpath(project_root_path, "Project.toml")))

using Logging
using Sockets
using HTTP
using JSON
using DelimitedFiles
using ArgParse
using DataLinter
using CSV

# Default forecaster port
const SERVER_HTTP_PORT = 10000


# Logging
const LOG_LEVEL = Logging.Debug
global_logger(ConsoleLogger(stdout, LOG_LEVEL))

# Linting request values
const DEFAULT_LINTERS = ["all"]
const DEFAULT_SHOW_NA = false
const DEFAULT_SHOW_STATS = false
const DEFAULT_SHOW_PASSING = false

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
        "--config-path"
        help = "Path for the configuration file"
        arg_type = String
        default = ""
        "--kb-path"
        help = "Path for the KB file"
        arg_type = String
        default = ""
        "--log-level"
        help = "logging level"
        default = "debug"
    end
    return parse_args(args, s)
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
    log_levels = Dict(
        "debug" => Logging.Debug,
        "info" => Logging.Info,
        "warning" => Logging.Warn,
        "error" => Logging.Error
    )
    logger = ConsoleLogger(stdout, get(log_levels, lowercase(args["log-level"]), Logging.Info))
    global_logger(logger)

    # Get IP, port, directory
    http_ip = args["http-ip"]
    http_port = args["http-port"]
    configpath = args["config-path"]
    if isempty(configpath) || !isfile(configpath)
        @warn "Config file not correctly specified (--config-path),  defaults will be used."
    end
    kbpath = args["kb-path"]
    if isempty(kbpath) || !isfile(kbpath)
        @debug "KB file not correctly specified (--kb-path), defaults will be used."
    end

    # Start I/O server(s) #
    # ################### #
    linting_server(http_ip, http_port; configpath = configpath, kbpath = kbpath)
    return 0
end


function linting_server(addr = "127.0.0.1", port = SERVER_HTTP_PORT; configpath = "", kbpath = "")
    #Checks
    if port <= 0 || port == nothing
        @error "HTTP port $(repr(port)) is not valid. Exiting..."
    end
    # Assign addresses: try IPv4 first, IPv6 second
    addr = try
        IPv4(addr)
    catch
        try
            IPv6(addr)
        catch
            @warn "HTTP IP $addr is not valid, using `localhost`..."
            Sockets.localhost
        end
    end

    # Define REST endpoints to dispatch to "service" functions
    ROUTER = HTTP.Router()
    HTTP.register!(ROUTER, "GET", "/*", noop_req_handler)
    HTTP.register!(ROUTER, "GET", "/api/kill", kill_req_handler)
    HTTP.register!(ROUTER, "POST", "/*", noop_req_handler)
    HTTP.register!(ROUTER, "POST", "/api/lint", linting_handler_wrapper(configpath, kbpath))

    # Start serving requests
    @info "• Data linting server online @$addr:$port..."
    return HTTP.serve(addr, port, readtimeout = 0) do http_req::HTTP.Request
        handler_output = try
            ROUTER(http_req)
        catch e
            @debug "Error handling HTTP request.\n$e"
            -1  # will be visible in HTTP headers, "Status"=>"ERROR"
        end
        if handler_output === nothing
            # An unsupported endpoint was called
            return HTTP.Response(501, ["Access-Control-Allow-Origin" => "*", "Status" => "OK"], body = "")
        elseif handler_output isa String
            # All OK, send request to search server and get response
            return HTTP.Response(200, ["Access-Control-Allow-Origin" => "*", "Status" => "OK"], body = handler_output)
        elseif handler_output isa Int
            _status = ifelse(handler_output == 0, "OK", "ERROR")
            return HTTP.Response(200, ["Access-Control-Allow-Origin" => "*", "Status" => _status], body = "")
        else
            return HTTP.Response(400, ["Access-Control-Allow-Origin" => "*"], body = "")  # failsafe (not used)
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


linting_handler_wrapper(configpath, kbpath) = (req::HTTP.Request) -> begin
    @debug "HTTP request $(req.target) received."
    config = if !isempty(configpath)
        try
            DataLinter.Configuration.load_config(configpath)
        catch e
            @warn "Error loading the config @$configpath\n$e"
            nothing
        end
    end
    config !== nothing && @debug "config loaded @$configpath"
    kb = if !isempty(kbpath)
        try
            DataLinter.kb_load(kbpath)
        catch e
            @debug "Error loading the KB @$kbpath\n$e"
            nothing
        end
    end
    kb !== nothing && @debug "KB loaded @$kbpath"
    _request = try
        JSON.parse(IOBuffer(HTTP.payload(req)))
    catch e
        @debug "Could not parse HTTP request\n$e"
        return nothing
    end

    #JSON validation
    try
        @assert haskey(_request, "linter_input") "Missing \"linter_input\" key"
        @assert haskey(_request["linter_input"], "context") "Missing \"context\" key"
        @assert haskey(_request["linter_input"], "options") "Missing \"options\" key"
    catch e
        @warn "Malformed request:\n$e"
    end
    ctx = _request["linter_input"]["context"]
    opts = _request["linter_input"]["options"]

    # Read data from request
    data = try
        data_source = if ctx["data_type"] == "dataset"
                seekstart(IOBuffer(ctx["data"]))  # read data from HTTP request
            elseif ctx["data_type"] == "filepath"
                _path = abspath(expanduser(ctx["data"]))  # take the absolute pathabspath(expanduser(ctx["data"]))  # take the absolute path
                @assert ispath(_path) "No valid entity @$_path"
                _path
            else
                @error "Data type $(ctx["data_type"]) not supported"
            end
        CSV.read(data_source,
                 CSV.Tables.Columns,
                 delim=first(ctx["data_delim"]),
                 header=ctx["data_header"])
    catch e
        @debug "Error loading data\n$e"
        nothing
    end
    isnothing(data) && return nothing
    @debug "CSV data loaded and succesfully processed.\n$data"

    # Read code and options from request
    code = get(ctx, "code", nothing)
    linters = get(ctx, "linters", DEFAULT_LINTERS)
    show_passing = get(opts, "show_passing", DEFAULT_SHOW_PASSING)
    show_stats = get(opts, "show_stats", DEFAULT_SHOW_STATS)
    show_na = get(opts, "show_na", DEFAULT_SHOW_NA)
    try
        buffer = IOBuffer()
        data_ctx = DataLinter.DataInterface.build_data_context(data, code)
        lintout = DataLinter.lint(data_ctx, kb; config, linters)
        process_output(lintout; buffer, show_passing, show_stats, show_na)
        score = DataLinter.OutputInterface.score(lintout; normalize = true)
        string_buf = read(seekstart(buffer), String)
        return JSON.json("linting_output" => string_buf)
    catch e
        @warn "Linting error: $e"
        return nothing
    end
end


##############
# Run server #
##############
Base.exit_on_sigint(false)
if abspath(PROGRAM_FILE) == @__FILE__
    try
        real_main()
    catch e
        "Exception $e caught, exiting..."
        return 1
    end
end

end  # module
