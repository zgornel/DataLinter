module OutputText

import ..OutputInterface: TextOutputType, WARN_LEVEL_TO_NUM, get_status_string
import ..LinterCore: Linter, process_output,
    AbstractCheck, PassedCheck, FailedCheck, NotAvailableCheck

"""
    process_output(lintout; buffer=stdout, show_stats=false, show_passing=false, show_na=false, pretty_print=false)

Process linting output for display. The function takes the linter output `lintout` and prints
lints to `buffer`. If `show_stats`, `show_passing` and `show_na` are set to `true`, the function
will print statistics over the checks, the checks that passed and the ones that could not be applied
respectively. If `pretty_print` is true, the output is formatted to be visually more appealing. Unless `pretty_print = true`, `show_stats` is ignored.
"""
function process_output(
        lintout,
        ::Type{<:TextOutputType};
        buffer = stdout,
        show_stats = false,
        show_passing = false,
        show_na = false,
        pretty_print = false
    )
    n_linters = map(lo -> lo[1][1].name, lintout) |> length ∘ unique
    n_linters_na = map(lo -> lo[1][1].name, filter(lo -> isa(lo[2], NotAvailableCheck), lintout)) |> length ∘ unique
    n_linters_failed = map(lo -> lo[1][1].name, filter(lo -> isa(lo[2], FailedCheck), lintout)) |> length ∘ unique
    n_linters_passed = map(lo -> lo[1][1].name, filter(lo -> isa(lo[2], PassedCheck), lintout)) |> length ∘ unique
    sorted_out = sort(lintout, by = l -> get(WARN_LEVEL_TO_NUM, (l[1][1]).warn_level, 0), rev = true)
    for ((linter, loc_name), result) in sorted_out
        msg, color, bold = get_text_formatting(result, linter)
        if !(result isa NotAvailableCheck)
            if result isa FailedCheck
                _print(linter, result, buffer, loc_name, pretty_print; msg, color, bold)
            elseif show_passing
                _print(linter, result, buffer, loc_name, pretty_print; msg, color, bold)
            end
        else
            if show_na
                _print(linter, result, buffer, loc_name, pretty_print; msg, color, bold)
            end
        end
    end
    if show_stats && pretty_print
        printstyled(buffer, "Total of $n_linters linters:")
        printstyled(buffer, " $n_linters_passed Pass", bold = true, color = :green)
        printstyled(buffer, ",")
        if n_linters_failed > 0
            printstyled(buffer, " $n_linters_failed Fail", bold = true, color = :red)
        else
            printstyled(buffer, " $n_linters_failed Fail")
        end
        printstyled(buffer, ", $n_linters_na N/A\n")
    end
    return nothing
end


print_buffer(buf::IOBuffer) = print(stdout, read(seekstart(buf), String))

_print(linter::Linter, result::FailedCheck, buffer, loc_name, pretty_print; msg = "", color = :default, bold = :false) = begin
    if pretty_print
        printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
        printstyled(buffer, "$(rpad(loc_name, 20)) "; color, bold)
        printstyled(buffer, "$(linter.failure_message(loc_name, result))\n"; color, bold)
    else
        printstyled(buffer, "$(linter.name):$(linter.warn_level):$loc_name:$(linter.failure_message(loc_name, result))\n")
    end
end

_print(linter::Linter, result::PassedCheck, buffer, loc_name, pretty_print; msg = "", color = :default, bold = :false) = begin
    if pretty_print
        printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
        printstyled(buffer, "$(rpad(loc_name, 20)) "; color = color, bold)
        printstyled(buffer, "$(linter.correct_message(loc_name, result))\n"; color, bold)
    else
        printstyled(buffer, "$loc_name:$(linter.warn_level):$(linter.name):$(linter.failure_message(loc_name, result))\n")
    end
end

_print(linter::Linter, result::NotAvailableCheck, buffer, loc_name, pretty_print; msg = "", color = :default, bold = :false) = begin
    if pretty_print
        printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
        printstyled(buffer, "$(rpad(loc_name, 20)) "; color, bold)
        printstyled(buffer, "linter $(get_status_string(result)) for '$(loc_name)'\n"; color, bold)
    else
        printstyled(buffer, "$loc_name:$(linter.warn_level):$(linter.name):$(linter.failure_message(loc_name, result))\n")
    end
end


get_text_formatting(::FailedCheck, linter::Linter) = begin
    (linter.warn_level == "warning") && (return (msg = "! warning", color = :light_yellow, bold = false))
    (linter.warn_level == "info") && (return (msg = "• info", color = :light_cyan, bold = false))
    (linter.warn_level == "important") && (return (msg = "× important", color = :light_magenta, bold = false))
    (linter.warn_level == "experimental") && (return (msg = "• experimental", color = :blue, bold = false))
    (linter.warn_level ∉ keys(WARN_LEVEL_TO_NUM)) && (return (msg = "• unknown", color = :default, bold = false))
end

get_text_formatting(::PassedCheck, linter::Linter) = begin
    return (msg = "✓ pass", color = :default, bold = false)
end

get_text_formatting(::NotAvailableCheck, linter::Linter) = begin
    return (msg = "• n/a", color = :gray, bold = false)
end


end
