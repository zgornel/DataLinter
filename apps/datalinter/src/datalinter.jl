#!/bin/julia
#
module datalinter

using Pkg
project_root_path = abspath(joinpath(splitpath(@__FILE__)[1:end-4]...))
Pkg.activate(project_root_path)

using Logging
using ArgParse
using DataLinter



# Function that parses Garamond's unix-socket client arguments
function get_arguments(args::Vector{String})
	s = ArgParseSettings()
	@add_arg_table! s begin
        "input(s)"
            help = "Input(s): file(s) to be linted; Note: only delimited files supported ATM"
            required = true
            nargs = '+'  # at least one value required
            arg_type = String
            action = :store_arg
        "--kb-path"
            help = "Path to knowledge base '.toml' file"
            default = ""
            arg_type = String
        ###"--config-path"
        ###    help = "Path to linter configuration '.toml' file"
        ###    default = ""
        ###    arg_type = String
        ###"--output-type"
        ###    help = "Type of output; available: 'text', 'json', 'html'"
        ###    arg_type = Symbol
        ###    default = :text
        ###"--lint-level"
        ###    help = "linting level (info/warn/error)"
        ###    default = "info"
        "--log-level"
            help = "logging level"
            default = "error"
        "--version", "-v"
            help = "prints version"
            action = :store_true
        "--timed", "-t"
            help = "prints timings"
            action = :store_true
        "--print-exceptions"
            help = "print encountered exceptions while linting"
            action = :store_true
	end
	return parse_args(args,s)
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
        print("Data linter v$(DataLinter.version()).\n")
        return 0
    end
    print_exceptions = args["print-exceptions"]
    _timed = args["timed"]
    # Logging
    log_levels = Dict("debug" => Logging.Debug,
                      "info" => Logging.Info,
                      "warning" => Logging.Warn,
                      "error" => Logging.Error)

    log_level = get(log_levels, lowercase(args["log-level"]), Logging.Warn)
    logger = ConsoleLogger(stdout, log_level)
    global_logger(logger)
    ### Lint input(s)
    kbpath = args["kb-path"]
    filepaths = unique!(args["input(s)"])
    for filepath in abspath.(filepaths)
        try
            _t = @timed begin
                DataLinter.cli_linting_workflow(filepath, kbpath)
            end
            if _timed
                _, _time, _bytes, _gctime, _ = _t;
                println("  Completed in $_time seconds, $((_bytes/1024^2)) MB allocated, $(100*_gctime)% gc time")
            end
        catch e
            if print_exceptions
                @error "Linting failed for '$filepath':\n$(repeat("-",10))\n$e"
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

if occursin("debugger",main_script_file) || main_script_file == @__FILE__
    real_main()
end

end  # module

