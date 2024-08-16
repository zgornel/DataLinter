module OutputInterface

import ..LinterCore: process_output

function process_output(lintout; buffer=stdout, show_passing=false)
    n_failures = 0
    n_rules = length(unique(map(x->x[1][1].name, lintout)))
    ignored_rules = []
    for ((rule, v_name), result) in lintout
        applicable = !isnothing(result)
        !applicable && push!(ignored_rules, rule.name)
        #TODO: Explicitly represent dependency on rule (KB) structure
        msg, color, bold = _get_rule_print_options(rule, result, applicable)
        if result != rule.correct_if
            n_failures+= 1
            printstyled(buffer, "  $msg\t($(rule.name))\t"; color, bold)
            printstyled(buffer,"$(rule.message(v_name))\n")
        elseif show_passing
            printstyled(buffer, "  $msg\t($(rule.name))\t"; color, bold)
            printstyled(buffer,"$(rule.message(v_name))\n")
        end
    end
    n_rules_ignored = length(unique(ignored_rules))
    printstyled(buffer, "$n_failures ", bold=true)
    printstyled(" data linting issues found. $(n_rules-n_rules_ignored) (of $n_rules) rules applied.\n")
end


_get_rule_print_options(rule, result, applicable) = begin
    if applicable
        if result != rule.correct_if
            (rule.warn_level == "warning") && ( return (msg="warn", color=:yellow, bold=true) )
            (rule.warn_level == "info") && ( return (msg="info", color=:cyan, bold=true) )
        else
            # rule passed
            return (msg="pass", color=:default, bold=false)
        end
    else
        return (msg="not applicable", color=:gray, bold=false)
    end
end

end  # module
