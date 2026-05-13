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


"""
    process_output(lintout; buffer=stdout, show_stats=false, show_passing=false, show_na=false)

Process linting output for display. The function takes the linter output `lintout` and prints
lints to `buffer`. If `show_stats`, `show_passing` and `show_na` are set to `true`, the function
will print statistics over the checks, the checks that passes and the ones that could not be applied
respectively.
"""
function process_output(
        lintout;
        buffer = stdout,
        show_stats = false,
        show_passing = false,
        show_na = false
    )
    n_linters = map(lo -> lo[1][1].name, lintout) |> length ∘ unique
    n_linters_applied = map(lo -> lo[1][1].name, filter(lo -> !isa(lo[2], NotAvailableCheck), lintout)) |> length ∘ unique
    n_linters_na = n_linters - n_linters_applied
    sorted_out = sort(lintout, by = l -> get(WARN_LEVEL_TO_NUM, (l[1][1]).warn_level, 0), rev = true)
    give_reason_for_na(result) = result.info === nothing ? "*not applicable*" : "*FAILED*"
    failed_linters = Symbol[]
    for ((linter, loc_name), result) in sorted_out
        msg, color, bold = _print_options(result, linter)
        if !(result isa NotAvailableCheck)
            if result isa FailedCheck  # linter failed
                if linter.name ∉ failed_linters
                    push!(failed_linters, linter.name)
                end
                printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
                printstyled(buffer, "$(rpad(loc_name, 20)) "; color, bold)
                printstyled(buffer, "$(linter.failure_message(loc_name, result))\n"; color, bold)
            elseif show_passing
                printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
                printstyled(buffer, "$(rpad(loc_name, 20)) "; color = color, bold)
                printstyled(buffer, "$(linter.correct_message(loc_name, result))\n"; color, bold)
            end
        else
            if show_na
                printstyled(buffer, "$(rpad("$msg", 15))\t$(rpad("($(linter.name))", 30))\t"; color, bold)
                printstyled(buffer, "$(rpad(loc_name, 20)) "; color, bold)
                printstyled(buffer, "linter $(give_reason_for_na(result)) for '$(loc_name)'\n"; color, bold)
            end
        end
    end
    if show_stats
        n_failures = length(failed_linters)
        printstyled(buffer, "Total of $n_linters linters:")
        printstyled(buffer, " $(n_linters - n_failures - n_linters_na) Pass", bold = true, color = :green)
        printstyled(buffer, ",")
        if n_failures > 0
            printstyled(buffer, " $n_failures Fail", bold = true, color = :red)
        else
            printstyled(buffer, " $n_failures Fail")
        end
        printstyled(buffer, ", $n_linters_na N/A\n")
    end
    return nothing
end


print_buffer(buf::IOBuffer) = print(stdout, read(seekstart(buf), String))


_print_options(::FailedCheck, linter::Linter) = begin
    (linter.warn_level == "warning") && (return (msg = "! warning", color = :light_yellow, bold = false))
    (linter.warn_level == "info") && (return (msg = "• info", color = :light_cyan, bold = false))
    (linter.warn_level == "important") && (return (msg = "× important", color = :light_magenta, bold = false))
    (linter.warn_level == "experimental") && (return (msg = "• experimental", color = :blue, bold = false))
    (linter.warn_level ∉ keys(WARN_LEVEL_TO_NUM)) && (return (msg = "• unknown", color = :default, bold = false))
end

_print_options(::PassedCheck, linter::Linter) = begin
    return (msg = "✓ pass", color = :default, bold = false)
end

_print_options(::NotAvailableCheck, linter::Linter) = begin
    return (msg = "• n/a", color = :gray, bold = false)
end

end  # module
