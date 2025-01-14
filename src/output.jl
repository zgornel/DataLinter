module OutputInterface

using StatsBase
import ..LinterCore: process_output

"""
Structure that maps a warning level to a numeric value.
This can be used to obtain an numeric estimate of the issues
over a dataset.
"""
const WARN_LEVEL_TO_NUM = Dict("info" => 1,
                               "warning" => 3,
                               "important" => 5,
                               "experimental" => 0)

"""
Returns a score corresponding to the severity of the issues found in
the dataset. The score is based on the `WARN_LEVEL_TO_NUM` mapping.
"""
function score(lintout; normalize=true)
    vals = (WARN_LEVEL_TO_NUM[l.warn_level] for ((l, _), v) in lintout if v==false)
    return ifelse(normalize, mean(vals), sum(vals))
end


"""
    process_output(lintout; buffer=stdout, show_stats=false, show_passing=false, show_na=false)

Process linting output for display. The function takes the linter output `lintout` and prints
lints to `buffer`. If `show_stats`, `show_passing` and `show_na` are set to `true`, the function
will print statistics over the checks, the checks that passes and the ones that could not be applied
respectively.
"""
function process_output(lintout;
                        buffer=stdout,
                        show_stats=false,
                        show_passing=false,
                        show_na=false)
    n_failures = 0
    n_linters = map(lo->lo[1][1].name, lintout) |> length∘unique
    n_linters_applied = map(lo->lo[1][1].name, filter(lo->lo[2]!=nothing, lintout)) |> length∘unique
    n_linters_na = n_linters - n_linters_applied
    sorted_out = sort(lintout, by=l->WARN_LEVEL_TO_NUM[(l[1][1]).warn_level], rev=true)
    for ((linter, loc_name), result) in sorted_out
        applicable = !isnothing(result)
        msg, color, bold = _print_options(linter, result, applicable)
        if applicable
            if !result  # linter failed
                n_failures+= 1
                printstyled(buffer, "$(rpad("$msg",15))\t$(rpad("($(linter.name))",20))\t"; color, bold)
                printstyled(buffer, "$(rpad(loc_name,20)) "; color=color, bold=true)
                printstyled(buffer,"$(linter.failure_message(loc_name))\n"; color, bold=true)
            elseif show_passing
                printstyled(buffer, "$(rpad("$msg",15))\t$(rpad("($(linter.name))",20))\t"; color, bold)
                printstyled(buffer, "$(rpad(loc_name,20)) "; color=color, bold=true)
                printstyled(buffer,"$(linter.correct_message(loc_name))\n"; color, bold=true)
            end
        else
            if show_na
                printstyled(buffer, "$(rpad("$msg",15))\t$(rpad("($(linter.name))",20))\t"; color, bold)
                printstyled(buffer, "$(rpad(loc_name,20)) "; color=color, bold=true)
                printstyled(buffer,"linter not applicable for '$(loc_name)'\n"; color, bold=true)
            end
        end
    end
    if show_stats
        printstyled(buffer, "$n_failures", bold=true)
        printstyled(buffer, " $(ifelse(n_failures==1, "issue", "issues")) found from $n_linters linters applied ($n_linters_applied OK, $n_linters_na N/A) .\n")
    end
    return nothing
end


print_buffer(buf::IOBuffer) = print(stdout, read(seekstart(buf), String))


_print_options(linter, result, applicable) = begin
    if applicable
        if !result
            (linter.warn_level == "warning") && ( return (msg="! warning", color=:yellow, bold=true) )
            (linter.warn_level == "info") && ( return (msg="• info", color=:cyan, bold=true) )
            (linter.warn_level == "important") && ( return (msg="× important", color=:red, bold=true) )
            (linter.warn_level == "experimental") && ( return (msg="• experimental", color=:blue, bold=true) )
        else
            # linter passed
            return (msg="✓ pass", color=:default, bold=true)
        end
    else
        return (msg="• n/a", color=:gray, bold=true)
    end
end

end  # module
