module OutputInterface

using StatsBase
import ..LinterCore: Linter, process_output,
    AbstractCheck, PassedCheck, FailedCheck, NotAvailableCheck

"""
Structure that maps a warning level to a numeric value.
This can be used to obtain an numeric estimate of the issues
over a dataset.
"""
const WARN_LEVEL_TO_NUM = Dict(
    "info" => 3,
    "warning" => 5,
    "important" => 10,
    "experimental" => 1
)

"""
Returns a score corresponding to the severity of the issues found in
the dataset. The score is based on the `WARN_LEVEL_TO_NUM` mapping.
"""
function score(lintout; normalize = true)
    vals = (
        get(WARN_LEVEL_TO_NUM, l.warn_level, 0)
            for ((l, _), v) in lintout if v isa FailedCheck
    )
    return if !isempty(vals)
        ifelse(normalize, mean(vals), sum(vals))
    else
        0
    end
end


# Types for different outputs
abstract type AbstractOutputType end

struct TextOutputType <: AbstractOutputType end

struct JSONOutputType <: AbstractOutputType end

struct HTMLOutputType <: AbstractOutputType end

function infer_outputtype(output_type::Symbol)
    if output_type == :text
        return TextOutputType
    elseif output_type == :json
        return JSONOutputType
    elseif output_type == :html
        return HTMLOutputType
    else
        @debug "Could not infer output type, this will cause and exit...\n$e"
        return nothing
    end
end

function process_output(
        lintout;
        output_type = :text,
        buffer = stdout,
        show_stats = false,
        show_passing = false,
        show_na = false,
        pretty_print = false
    )
    outputtype = infer_outputtype(output_type)
    if isnothing(outputtype)
        throw(ErrorException("'OutputInterface.process_output': Make sure output type is correctly specified and supported."))
    end
    # Call specialized i.e. plugin methods
    return process_output(
        lintout,
        outputtype;
        buffer,
        show_stats,
        show_passing,
        show_na,
        pretty_print
    )
end


end  # module
