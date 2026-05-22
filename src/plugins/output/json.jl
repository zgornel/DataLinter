module OutputJSON

using JSON

import ..OutputInterface: JSONOutputType
import ..LinterCore: Linter, process_output,
    AbstractCheck, PassedCheck, FailedCheck, NotAvailableCheck

# TODO Needs to write to buffer:
#   print(stdout, JSON.json("linting_output" => string_buf))


function process_output(
        lintout,
        ::Type{<:JSONOutputType};
        buffer = stdout,
        show_stats = false,
        show_passing = false,
        show_na = false,
        pretty_print = false
    )
    #    n_linters = map(lo -> lo[1][1].name, lintout) |> length ∘ unique
    #    n_linters_applied = map(lo -> lo[1][1].name, filter(lo -> !isa(lo[2], NotAvailableCheck), lintout)) |> length ∘ unique
    #    n_linters_na = n_linters - n_linters_applied
    #    sorted_out = sort(lintout, by = l -> get(WARN_LEVEL_TO_NUM, (l[1][1]).warn_level, 0), rev = true)
    #    give_reason_for_na(result) = result.info === nothing ? "*not applicable*" : "*FAILED*"
    #    failed_linters = Symbol[]
    #    for ((linter, loc_name), result) in sorted_out
    #        msg, color, bold = _print_options(result, linter)
    #        if !(result isa NotAvailableCheck)
    #            if result isa FailedCheck  # linter failed
    #                if linter.name ∉ failed_linters
    #                    push!(failed_linters, linter.name)
    #                end
    #                printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
    #                printstyled(buffer, "$(rpad(loc_name, 20)) "; color, bold)
    #                printstyled(buffer, "$(linter.failure_message(loc_name, result))\n"; color, bold)
    #            elseif show_passing
    #                printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
    #                printstyled(buffer, "$(rpad(loc_name, 20)) "; color = color, bold)
    #                printstyled(buffer, "$(linter.correct_message(loc_name, result))\n"; color, bold)
    #            end
    #        else
    #            if show_na
    #                printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
    #                printstyled(buffer, "$(rpad(loc_name, 20)) "; color, bold)
    #                printstyled(buffer, "linter $(give_reason_for_na(result)) for '$(loc_name)'\n"; color, bold)
    #            end
    #        end
    #    end
    #    if show_stats
    #        n_failures = length(failed_linters)
    #        printstyled(buffer, "Total of $n_linters linters:")
    #        printstyled(buffer, " $(n_linters - n_failures - n_linters_na) Pass", bold = true, color = :green)
    #        printstyled(buffer, ",")
    #        if n_failures > 0
    #            printstyled(buffer, " $n_failures Fail", bold = true, color = :red)
    #        else
    #            printstyled(buffer, " $n_failures Fail")
    #        end
    #        printstyled(buffer, ", $n_linters_na N/A\n")
    #    end
    return nothing
end

end  # module
