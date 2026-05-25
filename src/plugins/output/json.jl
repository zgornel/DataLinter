module OutputJSON

using JSON

import ..OutputInterface: JSONOutputType, WARN_LEVEL_TO_NUM, get_status_string
import ..LinterCore: Linter, process_output,
    AbstractCheck, PassedCheck, FailedCheck, NotAvailableCheck

function process_output(
        lintout,
        ::Type{<:JSONOutputType};
        buffer = stdout,
        show_passing = false,
        show_na = false,
        kwargs...
    )
    sorted_out = sort(lintout, by = l -> get(WARN_LEVEL_TO_NUM, (l[1][1]).warn_level, 0), rev = true)
    result_dicts = Dict{String,String}[]
    for ((linter, loc_name), result) in sorted_out
        if !(result isa NotAvailableCheck)
            if result isa FailedCheck
                push!(result_dicts, _make_result_dict(linter, result, loc_name))
            elseif show_passing
                push!(result_dicts, _make_result_dict(linter, result, loc_name))
            end
        else
            if show_na
                push!(result_dicts, _make_result_dict(linter, result, loc_name))
            end
        end
    end
    seekstart(buffer)
    print(buffer, JSON.json(Dict("linting_output" => result_dicts)))
    return nothing
end

_make_result_dict(linter, result, loc_name) = begin
    return Dict{String, String}(
        "name" => string(linter.name),
        "warn_level" => linter.warn_level,
        "location" => loc_name,
        "description" => linter.description,
        "failure_message" => linter.failure_message(loc_name, result),
        "status" => get_status_string(result),
    )
end

end  # module
