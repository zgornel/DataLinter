@reexport module LinterCore

export AbstractLinterContext

# Data Interface
abstract type AbstractDataContext end

# Output Interface

# KB Interface
abstract type AbstractKnowledgeBase end


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
            push!(lintout, (rule, v) => result)
        end
    end
    return lintout
end

function apply(rule, v; elementwise=false)
    return if elementwise
        rule.(v)
    else
        rule(v)
    end
end

function applicable(rule, variables)
    #TODO: implement this
    return true
end


function get_rules(kb, ctx)
    #TODO: implement this
    return [x->x, x->x^2]
end


function variabilize(ctx)
    return (v for v in ctx.data)
end

end  # module
