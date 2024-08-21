module OutputInterface

import ..LinterCore: process_output

function process_output(lintout; buffer=stdout, show_stats=false, show_passing=false)
    n_failures = 0
    n_linters = length(unique(map(x->x[1][1].name, lintout)))
    ignored_linters = []
    for ((linter, v_name), result) in lintout
        applicable = !isnothing(result)
        !applicable && push!(ignored_linters, linter.name)
        #TODO: Explicitly represent dependency on linter (KB) structure
        msg, color, bold = _print_options(linter, result, applicable)
        if applicable
            if !result  # linter failed
                n_failures+= 1
                printstyled(buffer, "$msg\t($(linter.name))\t"; color, bold)
                printstyled(buffer,"$(linter.failure_message(v_name))\n")
            elseif show_passing
                printstyled(buffer, "$msg\t($(linter.name))\t"; color, bold)
                printstyled(buffer,"$(linter.correct_message(v_name))\n")
            end
       end
    end
    if show_stats
        n_linters_ignored = length(unique(ignored_linters))
        printstyled(buffer, "$n_failures", bold=true)
        printstyled(buffer, " data linting issues found. $(n_linters-n_linters_ignored) (of $n_linters) linters applied.\n")
    end
end


print_buffer(buf::IOBuffer) = print(stdout, read(seekstart(buf), String))


_print_options(linter, result, applicable) = begin
    if applicable
        if !result
            (linter.warn_level == "warning") && ( return (msg="× warn", color=:yellow, bold=true) )
            (linter.warn_level == "info") && ( return (msg="• info", color=:cyan, bold=true) )
        else
            # linter passed
            return (msg="∨ pass", color=:default, bold=true)
        end
    else
        return (msg="not applicable", color=:gray, bold=false)
    end
end

end  # module
