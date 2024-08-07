@reexport module LinterCore
using DataFrames

export AbstractLinterContext

# Data Interface
abstract type AbstractDataContext end
function variabilize end  # returns an iterable Pairs(:variable_name => [vector of variable values])

# KB Interface
abstract type AbstractKnowledgeBase end
function get_rules end

# Output Interface
function process_output end


# Main linting function
# 'ctx' contains data, config, etc
function lint(ctx::AbstractDataContext, kb::AbstractKnowledgeBase)
    lintout = []
    for rule in get_rules(kb, ctx)
        for v in variabilize(ctx)
            # variablize creates single variables but also combines them
            # in a way that rules may be applicable
            result = if applicable(rule, v)
                apply(rule, v; elementwise=ctx.elementwise)
            else
                nothing
            end
            v_name, _ = v
            push!(lintout, (rule, v_name) => result)
        end
    end
    process_output(lintout)
    return lintout
end


function apply(rule, v; elementwise=false)
    v_name, v_values = v
    out_f = if elementwise
                rule.f.(v_values)
             else
                rule.f(v_values)
             end
    return out_f == rule.correct_if
end

function applicable(rule, variables)
    #TODO: implement this
    return true
end

end  # module
