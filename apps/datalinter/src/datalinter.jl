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
        nargs = '+'  # at least one value required
        arg_type = String
        action = :store_arg
        "--kb-path"
        help = "path to knowledge base '.toml' file"
        default = ""
        arg_type = String
        "--config-path"
        help = "path to linter configuration '.toml' file"
        default = ""
        arg_type = String
        "--log-level"
        help = "logging level"
        default = "error"
        "--linters"
        help = "linter groups to use. Avaliable: \"google\", \"experimental\", \"all\""
        nargs = '*'
        default = ["all"]
        arg_type = String
        action = :store_arg
        "--version", "-v"
        help = "prints version"
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
        return 1
    end
    return 0
end


function real_main()
    # Parse command line arguments
    args = get_arguments(ARGS)
    # If version present, print and exit
    ask_version = args["version"]
    if ask_version
        print(DataLinter.printable_version(; commit = "906f2df*", ver = DataLinter.DEFAULT_VERSION))
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
    kbpath = args["kb-path"]
    configpath = args["config-path"]
    filepaths = unique!(args["input(s)"])
    linters = unique!(args["linters"])
    if isempty(filepaths)
        @error "Provide at least one file to lint."
    end
    for filepath in abspath.(filepaths)
        try
            _t = @timed begin
                DataLinter.cli_linting_workflow(
                    filepath,
                    kbpath,
                    configpath;
                    buffer = stdout,
                    show_stats = true,
                    show_passing = false,
                    show_na = false,
                    progress = progress,
                    linters = linters
                )
            end
            if _timed
                _, _time, _bytes, _gctime, _ = _t
                println("  Completed in $_time seconds, $((_bytes / 1024^2)) MB allocated, $(100 * _gctime)% gc time")
            end
        catch e
            if print_exceptions
                @error "Linting failed for '$filepath':\n$(repeat("-", 10))\n$e"
            else
                @error "Linting failed for '$filepath'. Use '--print-exceptions' for more info."
            end
        end
    end
    ###

    return 0
end


##############
# Run client #
##############

main_script_file = abspath(PROGRAM_FILE)

if occursin("debugger", main_script_file) || main_script_file == @__FILE__
    real_main()
end

end  # module
