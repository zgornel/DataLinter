@reexport module LinterCore
using DataFrames

export AbstractLinterContext, lint

# Data Interface
abstract type AbstractDataContext end
function variabilize end  # returns an iterable Pairs(:variable_name => [vector of variable values])
function context_code end

# KB Interface
abstract type AbstractKnowledgeBase end
function build_linters end

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
    for linter in build_linters(kb, ctx)
        code = context_code(ctx)
        for v in variabilize(ctx)
            v_name, _ = v
            # variablize creates single variables but also combines them
            # in a way that individual linters may be applicable
            result = if applicable(linter, v, code)
                #TODO: Implement mechanism for working with ctx.code
                apply(linter, v, code; elementwise=ctx.elementwise)
            else
                nothing
            end
            push!(lintout, (linter, v_name) => result)
        end
    end
    process_output(lintout;buffer, show_passing, show_stats)
    return lintout
end


function apply(linter, v, code; elementwise=false)
    v_name, v_values = v
    #TODO: use try-catch
    #TODO: parse `code` usable in some way by the linters' functions
    #      i.e. key terms, ontology concepts etc.
    out_f = if elementwise
                linter.f.(v_values, code)
             else
                linter.f(v_values, code)
             end
    return out_f == linter.correct_if
end


function applicable(linter, variable, code)
    if linter.name == :no_negative_values && code !== nothing
        return false
    end
    return true
end

end  # module
