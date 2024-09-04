@reexport module LinterCore
using DataFrames

export AbstractLinterContext, lint, version

# Data Interface
abstract type AbstractDataContext end
function build_data_iterator end  # returns an iterables over data
function context_code end
@Base.kwdef struct DataIterator
    column_iterator     # iterate over columns with elements `((name, eltype), [values,...])`
    row_iterator        # iterate over rows with elements `[name => value, name=>value, ...]`
    dataref             # reference to the DataFrame
end
function columnname end # Returns the name of a 'column' element of the `DataIterator`

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
    lintout = []  # TODO: Improve this structure to something more workable
                  #       that includes timings, outputs, easy referencing i.e. Dict
    datait = build_data_iterator(ctx)
    for linter in build_linters(kb, ctx)
        #_t = @timed begin
                code = context_code(ctx)
                # 1. Apply over columns
                if applicable(linter, :column, code)
                    for col in datait.column_iterator
                        result = apply(linter, col, code)
                        push!(lintout, (linter, "column: $(columnname(col))") => result)
                    end
                end
                # 2. Apply over rows
                if applicable(linter, :row, code)
                    irow = 1
                    for row in datait.row_iterator
                        result = apply(linter, row, code)
                        if !isnothing(result) && !result  # skip trues or nothings as there may be too many
                            push!(lintout, (linter, "row: $irow") => result)
                        end
                        irow+= 1
                    end
                end
                # 3. Apply over whole dataset
                if applicable(linter, :dataset, code)
                    result = apply(linter, datait.dataref, code)
                    push!(lintout, (linter, "dataset") => result)
                end
        #end;
        #_, _time, _bytes, _gctime, _ = _t;
        #@show linter.name, _time, _bytes, _gctime
    end
    process_output(lintout; buffer, show_passing, show_stats, show_na)
    return lintout
end


apply(linter, data, code) = linter.correct_if(linter.f(data, code))  # Apply the linter!


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
    elseif linter.name == :long_tailed_distrib && iterable_type == :column
        return true
    elseif linter.name == :circular_domain && iterable_type == :column
        return true
    elseif linter.name == :uncommon_list_lengths && iterable_type == :column
        return true
    else
        return false
    end
end


function version()
    ver = v"0.1.0"
end

end  # module
