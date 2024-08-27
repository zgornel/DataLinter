module OutputInterface

import ..LinterCore: process_output

function process_output(lintout;
                        buffer=stdout,
                        show_stats=false,
                        show_passing=false,
                        show_na=false)
    n_failures = 0
    n_linters = map(lo->lo[1][1].name, lintout) |> length∘unique
    n_linters_applied = map(lo->lo[1][1].name, filter(lo->lo[2]!=nothing, lintout)) |> length∘unique
    for ((linter, loc_name), result) in lintout
        applicable = !isnothing(result)
        #TODO: Explicitly represent dependency on linter (KB) structure
        msg, color, bold = _print_options(linter, result, applicable)
        if applicable
            if !result  # linter failed
                n_failures+= 1
                printstyled(buffer, "$msg\t$(rpad("($(linter.name))",20))\t"; color, bold)
                printstyled(buffer,"$(linter.failure_message(loc_name))\n")
            elseif show_passing
                printstyled(buffer, "$msg\t$(rpad("($(linter.name))",20))\t"; color, bold)
                printstyled(buffer,"$(linter.correct_message(loc_name))\n")
            end
        else
            if show_na
                printstyled(buffer, "$msg\t$(rpad("($(linter.name))",20))\t"; color, bold)
                printstyled(buffer,"linter not applicable for $(loc_name)\n")
            end
        end
    end
    if show_stats
        printstyled(buffer, "$n_failures", bold=true)
        printstyled(buffer, " $(ifelse(n_failures==1, "issue", "issues")) found from $n_linters_applied data linters applied.\n")
    end
end


print_buffer(buf::IOBuffer) = print(stdout, read(seekstart(buf), String))


_print_options(linter, result, applicable) = begin
    if applicable
        if !result
            (linter.warn_level == "warning") && ( return (msg="! warn", color=:yellow, bold=true) )
            (linter.warn_level == "info") && ( return (msg="• info", color=:cyan, bold=true) )
            (linter.warn_level == "error") && ( return (msg="× error", color=:red, bold=true) )
        else
            # linter passed
            return (msg="✓ pass", color=:default, bold=true)
        end
    else
        return (msg="• n/a", color=:gray, bold=true)
    end
end

end  # module
