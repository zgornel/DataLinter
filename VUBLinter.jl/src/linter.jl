@reexport module LinterCore
using DataFrames

export AbstractLinterContext, lint

# Data Interface
abstract type AbstractDataContext end
function variabilize end  # returns an iterable Pairs(:variable_name => [vector of variable values])
function get_code end

# KB Interface
abstract type AbstractKnowledgeBase end
function get_rules end

# Output Interface
function process_output end


# Main linting function
# 'ctx' contains data, config, etc
function lint(ctx::AbstractDataContext,
              kb::AbstractKnowledgeBase;
              buffer=stdout,
              show_passing=false,
              show_stats=false)
    lintout = []
    for rule in get_rules(kb, ctx)
        code = get_code(ctx)
        for v in variabilize(ctx)
            v_name, _ = v
            # variablize creates single variables but also combines them
            # in a way that rules may be applicable
            result = if applicable(rule, v, code)
                #TODO: Implement mechanism for working with ctx.code
                apply(rule, v, code; elementwise=ctx.elementwise)
            else
                nothing
            end
            push!(lintout, (rule, v_name) => result)
        end
    end
    process_output(lintout;buffer, show_passing, show_stats)
    return lintout
end


function apply(rule, v, code; elementwise=false)
    v_name, v_values = v
    #TODO: use try-catch
    #TODO: parse `code` usable in some way by the rules' functions
    #      i.e. key terms, ontology concepts etc.
    out_f = if elementwise
                rule.f.(v_values, code)
             else
                rule.f(v_values, code)
             end
    return out_f == rule.correct_if
end


function applicable(rule, variable, code)
    if rule.name == :no_negative_values && code !== nothing
        return false
    end
    return true
end

end  # module
