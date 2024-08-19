module OutputInterface

import ..LinterCore: process_output

function process_output(lintout; buffer=stdout, show_stats=false, show_passing=false)
    n_failures = 0
    n_rules = length(unique(map(x->x[1][1].name, lintout)))
    ignored_rules = []
    for ((rule, v_name), result) in lintout
        applicable = !isnothing(result)
        !applicable && push!(ignored_rules, rule.name)
        #TODO: Explicitly represent dependency on rule (KB) structure
        msg, color, bold = _get_rule_print_options(rule, result, applicable)
        if applicable
            if !result  # rule failed
                n_failures+= 1
                printstyled(buffer, "$msg\t($(rule.name))\t"; color, bold)
                printstyled(buffer,"$(rule.failure_message(v_name))\n")
            elseif show_passing
                printstyled(buffer, "$msg\t($(rule.name))\t"; color, bold)
                printstyled(buffer,"$(rule.correct_message(v_name))\n")
            end
       end
    end
    if show_stats
        n_rules_ignored = length(unique(ignored_rules))
        printstyled(buffer, "$n_failures", bold=true)
        printstyled(buffer, " data linting issues found. $(n_rules-n_rules_ignored) (of $n_rules) rules applied.\n")
    end
end


print_buffer(buf::IOBuffer) = print(stdout, read(seekstart(buf), String))


_get_rule_print_options(rule, result, applicable) = begin
    if applicable
        if !result
            (rule.warn_level == "warning") && ( return (msg="× warn", color=:yellow, bold=true) )
            (rule.warn_level == "info") && ( return (msg="• info", color=:cyan, bold=true) )
        else
            # rule passed
            return (msg="∨ pass", color=:default, bold=true)
        end
    else
        return (msg="not applicable", color=:gray, bold=false)
    end
end

end  # module
