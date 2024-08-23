@reexport module LinterCore
using DataFrames

export AbstractLinterContext, lint

# Data Interface
abstract type AbstractDataContext end
function data_iterables end  # returns an iterables over data
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
        datait = data_iterables(ctx)
        # 1. Apply over columns
        for col in datait.column_iterator
            (colname, _), _ = col
            result = apply(linter, col, code)
            push!(lintout, (linter, "column: $colname") => result)
        end
        # 2. Apply over rows
        for (i, row) in enumerate(datait.row_iterator)
            result = apply(linter, row, code)
            if isnothing(result) # skip trues or nothings as there may be too many
                continue
            elseif result
                continue
            else
                push!(lintout, (linter, "row: $i") => result)
            end
        end
        # 3. Apply over whole dataset
        result = apply(linter, datait.dataref, code)
        push!(lintout, (linter, "dataset") => result)
    end
    process_output(lintout; buffer, show_passing, show_stats)
    return lintout
end


function apply(linter, data, code)
    # Functions that extract an informal description of the data type
    # to be used in the `applicable` function (also make checks more readable)
    get_data_type(::Pair) = :column
    get_data_type(::Vector{<:Pair}) = :row
    get_data_type(::Base.RefValue{DataFrames.DataFrame}) = :dataset

    data_type = get_data_type(data)
    result = if applicable(linter, data_type, code)
        out_f = linter.f(data, code)  # Apply the linter!
        linter.correct_if(out_f)      # Assert correctness of result
    else
        nothing
    end
    return result
end


function applicable(linter, data_type, code)
    if linter.name == :no_negative_values && data_type != :column
        return false
    elseif linter.name == :no_negative_values && data_type == :column && code !== nothing
        return false
    elseif linter.name == :no_missing_values && data_type != :column
        return false
    elseif linter.name == :int_as_float && data_type != :column
        return false
    else
        return true
    end
end

end  # module
