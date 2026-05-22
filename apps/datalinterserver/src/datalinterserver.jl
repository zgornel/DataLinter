module datalinterserver

project_root_path = abspath(joinpath(splitpath(@__FILE__)[1:(end - 4)]...))
Base.set_active_project(abspath(joinpath(project_root_path, "Project.toml")))

using Logging
using Sockets
using HTTP
using JSON
using ArgParse
using DataLinter
using CSV

const DEFAULT_LOG_LEVEL = Logging.Info
const SERVER_HTTP_PORT = 10000
const LOCALHOST_IP = "127.0.0.1"
const ERROR_IN_REQ_HANDLING = -1

# Linting request values
const DEFAULT_LINTERS = ["all"]
const DEFAULT_OUTPUT_TYPE = :text
const DEFAULT_SHOW_NA = false
const DEFAULT_SHOW_STATS = false
const DEFAULT_SHOW_PASSING = false
const DEFAULT_PRETTY_PRINT = true

function get_server_commandline_arguments(args::Vector{String})
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--http-port", "-p"
        help = "HTTP port"
        arg_type = Int
        default = SERVER_HTTP_PORT
        "--http-ip", "-i"
        help = "HTTP IP address"
        default = LOCALHOST_IP
        "--config-path"
        help = "path to linter configuration '.toml' file"
        arg_type = String
        default = ""
        "--kb-path"
        help = "path to knowledge base file"
        arg_type = String
        default = ""
        "--priming-data-path"
        help = "priming data file path"
        default = ""
        arg_type = String
        "--priming-code-path"
        help = "priming code file path"
        default = ""
        arg_type = String
        "--log-level"
        help = "logging level"
        default = "error"
        "--version", "-v"
        help = "prints version"
        action = :store_true
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
    # If version present, print and exit
    ask_version = args["version"]
    if ask_version
        println(DataLinter.printable_version(; commit = "192fce5*", ver = DataLinter.DEFAULT_VERSION))
        return 0
    end
    # Logging
    log_levels = Dict(
        "debug" => Logging.Debug,
        "info" => Logging.Info,
        "warning" => Logging.Warn,
        "error" => Logging.Error
    )
    logger = ConsoleLogger(stdout, get(log_levels, lowercase(args["log-level"]), DEFAULT_LOG_LEVEL))
    global_logger(logger)

    # Get IP, port, directory
    http_ip = args["http-ip"]
    http_port = args["http-port"]

    # Configuration loading
    configpath = args["config-path"]
    if isempty(configpath) || !isfile(configpath)
        @error "Config file not correctly specified (--config-path), will exit."
        return 2
    end
    config = try
        _config = DataLinter.Configuration.load_config(configpath)
        @debug "Config loaded @$configpath"
        _config
    catch e
        @error "Error loading the config @$configpath\n$e"
        return 2
    end

    # Knowledge base loading
    kbpath = args["kb-path"]
    kb = if isempty(kbpath) || !isfile(kbpath)
        @debug "KB file not correctly specified (--kb-path), using native knowledge."
        nothing
    else
        try
            DataLinter.kb_load(kbpath)
            @debug "KB loaded @$kbpath"
        catch e
            @debug "Error loading the KB @$kbpath\n$e"
            nothing
        end
    end

    # Priming
    priming_datapath = args["priming-data-path"]
    priming_codepath = args["priming-code-path"]
    if isempty(priming_datapath) || !isfile(priming_datapath)
        @debug "Priming data file missing or incorrectly specified. Will not perform priming."
    else
        # cli_linting_workflow already handles missing/wrong code paths
        @debug "Priming ...\n\t• data @$priming_datapath\n\t• code @$priming_codepath"
        DataLinter.cli_linting_workflow(
            priming_datapath,
            priming_codepath,
            kbpath,
            configpath;
            linters = DEFAULT_LINTERS,
            buffer = IOBuffer(),
            output_type = DEFAULT_OUTPUT_TYPE,
            show_stats = DEFAULT_SHOW_STATS,
            show_passing = DEFAULT_SHOW_PASSING,
            show_na = DEFAULT_SHOW_NA,
            pretty_print = false,
            progress = false
        )
        @debug "Priming done."
    end

    #######################
    # Start I/O server(s) #
    # ################### #
    linting_server(http_ip, http_port; config, kb)
    return 0
end


function linting_server(addr = LOCALHOST_IP, port = SERVER_HTTP_PORT; config = nothing, kb = nothing)
    #Checks
    if port <= 0
        @error "HTTP port $(repr(port)) is not valid. Exiting..."
        return 2
    end
    # Assign addresses: try IPv4 first, IPv6 second
    addr = try
        IPv4(addr)
    catch
        try
            IPv6(addr)
        catch
            @warn "HTTP IP $addr is not valid, using `localhost`..."
            IPv4(LOCALHOST_IP)
        end
    end

    # Define REST endpoints to dispatch to "service" functions
    ROUTER = HTTP.Router()
    HTTP.register!(ROUTER, "GET", "/**", noop_req_handler)
    HTTP.register!(ROUTER, "GET", "/api/kill", kill_req_handler)
    HTTP.register!(ROUTER, "POST", "/**", noop_req_handler)
    HTTP.register!(ROUTER, "POST", "/api/lint", linting_handler_wrapper(config, kb))

    # Start serving requests
    @info "• Data linting server online @$addr:$port..."
    return HTTP.serve(addr, port, readtimeout = 60) do http_req::HTTP.Request
        output = try
            ROUTER(http_req)
        catch e
            @debug "Error handling HTTP request.\n$e"
            ERROR_IN_REQ_HANDLING  # will be visible in HTTP headers, "Status"=>"ERROR"
        end

        # Process output
        response = _process_handler_output(output)
        return response
    end
end


# An unsupported endpoint was called
_process_handler_output(::Nothing, args...) = HTTP.Response(501, ["Access-Control-Allow-Origin" => "*", "Status" => "OK"], body = "")

# All OK, send request to search server and get response
_process_handler_output(output::String, args...) = HTTP.Response(200, ["Access-Control-Allow-Origin" => "*", "Status" => "OK"], body = output)

# Either something went wrong or server was killed
_process_handler_output(output::Int, args...) = if output == 0
    # Server was killed
    HTTP.Response(200, ["Access-Control-Allow-Origin" => "*", "Status" => "OK"], body = "")
elseif output == ERROR_IN_REQ_HANDLING
    # Error in request
    body = JSON.json(Dict("error" => "Bad request", "message" => "Failure in processing request."))
    HTTP.Response(400, ["Access-Control-Allow-Origin" => "*", "Status" => "ERROR"], body = body)
else
    # Failsafe (should not ever arrive here)
    HTTP.Response(400, ["Access-Control-Allow-Origin" => "*"], body = "")
end

# Failsafe (should not ever arrive here)
_process_handler_output(output, args...) = HTTP.Response(400, ["Access-Control-Allow-Origin" => "*"], body = "")

noop_req_handler(req::HTTP.Request) = nothing


kill_req_handler(req::HTTP.Request) = begin
    @info "Kill request received. Exiting in 1s..."
    @async begin
        sleep(1)  # some time to send back HTTP response
        exit()
    end
    return 0
end


linting_handler_wrapper(config, kb) = (req::HTTP.Request) -> begin
    @debug "HTTP request $(req.target) received."
    _request = try
        JSON.parse(IOBuffer(HTTP.payload(req)))
    catch e
        @debug "Could not parse HTTP request\n$e"
        return ERROR_IN_REQ_HANDLING
    end

    #JSON validation
    if !haskey(_request, "linter_input")
        @error "Missing \"linter_input\" key"
        return ERROR_IN_REQ_HANDLING
    end
    if !haskey(_request["linter_input"], "context")
        @error "Missing \"context\" key"
        return ERROR_IN_REQ_HANDLING
    end
    if !haskey(_request["linter_input"], "options")
        @error "Missing \"options\" key"
        return ERROR_IN_REQ_HANDLING
    end
    ctx = _request["linter_input"]["context"]
    opts = _request["linter_input"]["options"]

    # Build data context directly from request data information
    data_ctx = DataLinter.DataInterface.build_data_context(
        get(ctx, "data", nothing),
        get(ctx, "code", nothing);
        delim = first(ctx["data_delim"]),
        header = ctx["data_header"]
    )

    @debug "Data context loaded and succesfully:\n$data_ctx\n$(data_ctx.data)"

    # Read code and options from request
    linters = get(ctx, "linters", DEFAULT_LINTERS)
    output_type = get(opts, "output_type", DEFAULT_OUTPUT_TYPE)
    show_passing = get(opts, "show_passing", DEFAULT_SHOW_PASSING)
    show_stats = get(opts, "show_stats", DEFAULT_SHOW_STATS)
    show_na = get(opts, "show_na", DEFAULT_SHOW_NA)
    pretty_print = Symbol(get(opts, "pretty_print", DEFAULT_PRETTY_PRINT))
    try
        buffer = IOBuffer()
        lintout = DataLinter.lint(data_ctx, kb; config, linters)
        process_output(lintout; buffer, output_type, show_passing, show_stats, show_na, pretty_print)
        #score = DataLinter.OutputInterface.score(lintout; normalize = true)
        string_buf = read(seekstart(buffer), String)
        return JSON.json(Dict("linting_output" => string_buf))
    catch e
        @warn "Linting error: $e"
        return ERROR_IN_REQ_HANDLING
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
        @error "Exception $e caught, exiting..."
        return 1
    end
end

end  # module
