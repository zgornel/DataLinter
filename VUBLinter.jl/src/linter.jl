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
              show_stats=false,
              show_na=false)
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
    process_output(lintout; buffer, show_passing, show_stats, show_na)
    return lintout
end


function apply(linter, data, code)
    # Functions that extract an informal description of the data type
    # to be used in the `applicable` function (also make checks more readable)
    get_iterable_type(::Pair) = :column
    get_iterable_type(::Vector{<:Pair}) = :row
    get_iterable_type(::Base.RefValue{DataFrames.DataFrame}) = :dataset

    iterable_type = get_iterable_type(data)
    result = if applicable(linter, iterable_type, code)
        out_f = linter.f(data, code)  # Apply the linter!
        linter.correct_if(out_f)      # Assert correctness of result
    else
        nothing
    end
    return result
end


function applicable(linter, iterable_type, code)
    if linter.name == :negative_values && iterable_type == :column && code !== nothing
        return true
    elseif linter.name == :missing_values && iterable_type == :column
        return true
    elseif linter.name == :int_as_float && iterable_type == :column
        return true
    elseif linter.name == :datetime_as_string && iterable_type == :column
        return true
    elseif linter.name == :tokenizable_string && iterable_type == :column
        return true
    elseif linter.name == :number_as_string && iterable_type == :column
        return true
    elseif linter.name == :empty_example && iterable_type == :row
        return true
    elseif linter.name == :zipcodes_as_values && iterable_type == :column
        return true
    elseif linter.name == :duplicate_examples && iterable_type == :dataset
        return true
    elseif linter.name == :large_outliers && iterable_type == :column
        return true
    elseif linter.name == :enum_detector && iterable_type == :column
        return true
    elseif linter.name == :uncommon_signs && iterable_type == :column
        return true
    elseif linter.name == :tailed_distribution && iterable_type == :column
        return true
    elseif linter.name == :circular_domain && iterable_type == :column
        return true
    elseif linter.name == :uncommon_list_lengths && iterable_type == :column
        return true
    else
        return false
    end
end

end  # module
