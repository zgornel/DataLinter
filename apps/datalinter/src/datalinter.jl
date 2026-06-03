#!/bin/julia
#
module datalinter

using Pkg
project_root_path = abspath(joinpath(splitpath(@__FILE__)[1:(end - 4)]...))
Base.set_active_project(abspath(joinpath(project_root_path, "Project.toml")))

using Logging
using ArgParse
using DataLinter

function get_arguments(args::Vector{String})
    s = ArgParseSettings()
    @add_arg_table! s begin
        "input(s)"
        help = "input(s): file(s) to be linted; Note: only delimited files supported ATM"
        nargs = '*'  # any number of data inputs
        arg_type = String
        action = :store_arg
        "--code-path"
        help = "path to code file"
        default = ""
        arg_type = String
        "--kb-path"
        help = "path to knowledge base file"
        default = ""
        arg_type = String
        "--config-path"
        help = "path to linter configuration '.toml' file"
        default = ""
        arg_type = String
        "--output-type"
        help = "output type \"text\", \"json\" or \"html\""
        default = "text"
        arg_type = String
        "--log-level"
        help = "logging level"
        default = "error"
        "--linters"
        help = "linter groups to use. Avaliable: \"google\", \"extended\", \"r\", \"all\""
        nargs = '*'
        default = ["all"]
        arg_type = String
        action = :store_arg
        "--show-stats"
        help = "shows statistics"
        action = :store_true
        "--show-passing"
        help = "shows linters that passed"
        action = :store_true
        "--show-na"
        help = "shows linters that were not applicable"
        action = :store_true
        "--progress"
        help = "shows progress"
        action = :store_true
        "--timed", "-t"
        help = "prints timings"
        action = :store_true
        "--print-exceptions"
        help = "print encountered exceptions while linting"
        action = :store_true
        "--pretty-print"
        help = "print pretty"
        action = :store_true
        "--version", "-v"
        help = "prints version"
        action = :store_true
    end
    return parse_args(args, s)
end


########################
# Main module function #
########################
function julia_main()::Cint  # for compilation to executable
    try
        real_main()          # actual main function
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 2
    end
    return 0
end


function real_main()
    # Parse command line arguments
    args = get_arguments(ARGS)
    # If version present, print and exit
    ask_version = args["version"]
    if ask_version
        println(DataLinter.printable_version(; commit = "192fce5*", ver = DataLinter.DEFAULT_VERSION))
        return 0
    end
    progress = args["progress"]
    print_exceptions = args["print-exceptions"]
    _timed = args["timed"]
    # Logging
    log_levels = Dict(
        "debug" => Logging.Debug,
        "info" => Logging.Info,
        "warning" => Logging.Warn,
        "error" => Logging.Error
    )

    log_level = get(log_levels, lowercase(args["log-level"]), Logging.Warn)
    logger = ConsoleLogger(stdout, log_level)
    global_logger(logger)
    ### Lint input(s)
    codepath = args["code-path"]
    configpath = args["config-path"]
    if isempty(configpath) || !isfile(configpath)
        @error "Config file not correctly specified (--config-path), will exit."
        return 2
    end
    kbpath = args["kb-path"]
    if isempty(kbpath) || !isfile(kbpath)
        @debug "KB file not correctly specified (--kb-path), using native knowledge."
    end
    output_type = Symbol(args["output-type"])
    filepaths = unique!(args["input(s)"])
    linters = unique!(args["linters"])
    show_stats = args["show-stats"]
    show_passing = args["show-passing"]
    show_na = args["show-na"]
    pretty_print = args["pretty-print"]

    filepaths = if isempty(filepaths)
        @debug "No data files provide, code-only linting assumed."
        # filepaths is nothing, provided to build_data_context to create a CodeContext
        [nothing]
    else
        filepaths
    end
    buffer = ifelse(output_type == :text, stdout, IOBuffer())  # for nice styling with pretty printing
    for filepath in filepaths
        try
            _t = @timed begin
                # lintout is raw output, not used
                # can be potantially used as 'raw' output
                _filepath = if !isnothing(filepath)
                    abspath(filepath)
                else
                    filepath
                end
                _, lintout = DataLinter.cli_linting_workflow(
                    _filepath,
                    codepath,
                    kbpath,
                    configpath;
                    linters,
                    buffer,
                    output_type,
                    show_stats,
                    show_passing,
                    show_na,
                    pretty_print,
                    progress
                )
            end
            if output_type !== :text
                print(stdout, read(seekstart(buffer), String))
            end
            if _timed
                _, _time, _bytes, _gctime, _ = _t
                println("  Completed in $_time seconds, $((_bytes / 1024^2)) MB allocated, $(100 * _gctime)% gc time")
            end
        catch e
            if print_exceptions
                @warn "Linting failed for '$filepath':\n$(repeat("-", 10))\n$e"
            else
                @warn "Linting failed for '$filepath'. Use '--print-exceptions' for more info."
            end
            return 1
        end
    end
    ###

    return 0
end


##############
# Run client #
##############
Base.exit_on_sigint(false)

main_script_file = abspath(PROGRAM_FILE)

if occursin("debugger", main_script_file) || main_script_file == @__FILE__
    try
        real_main()
    catch e
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 2
    end
end

end  # module
