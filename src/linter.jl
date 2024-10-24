@reexport module LinterCore
using Tables
export AbstractLinterContext, lint, version

# Data Interface
abstract type AbstractDataContext end
function build_data_iterator end  # returns an iterables over data
function context_code end
@Base.kwdef struct DataIterator
    column_iterator     # iterate over columns with elements `((name, eltype), [values,...])`
    row_iterator        # iterate over rows with elements `[name => value, name=>value, ...]`
    tblref              # reference to the input data
end
function columnname end # Returns the name of a 'column' element of the `DataIterator`
function columntype end # Returns the type of a 'column' element of the `DataIterator`

# KB Interface
abstract type AbstractKnowledgeBase end
function build_linters end
@Base.kwdef struct Linter
    name::Symbol
    description::String
    f::Function
    failure_message::Function
    correct_message::Function
    warn_level::String
    correct_if::Function
end

Base.show(io::IO, linter::Linter) = begin
    func = last(split(string(linter.f),"."))
    print(io, "Linter (name=$(linter.name), f=$func)")
end


# Output Interface
function process_output end

# Config Interface
function load_config end
function linter_is_enabled end
function get_linter_kwargs end

# Main linting function
# 'ctx' contains data, config, etc
function lint(ctx::AbstractDataContext,
              kb::AbstractKnowledgeBase;
              config=nothing,
              buffer=stdout,
              show_passing=false,
              show_stats=false,
              show_na=false)
    # TODO: Improve the `lintout` structure to something more workable
    #       that includes timings, outputs, easy referencing i.e. Dict
    lintout = []
    datait = build_data_iterator(ctx)
    for linter in build_linters(kb, ctx)
        if linter_is_enabled(config, linter)
            linter_kwargs = get_linter_kwargs(config, linter)  # this injects configuration parameters into linter functions
            _t = @timed begin
                    code = context_code(ctx)
                    # Apply linter:
                    #  - run linter function
                    #  - compare result with the one stored in closure for correctness
                    #  - if the result is false i.e. mismatch in values, linter fails (warning displayed)
                    #  - if the result is true i.e. expexted value returned, linter passes
                    # 1. Apply over column
                    if applicable(linter, :column, code)
                        for (i, col) in enumerate(datait.column_iterator)
                            _name = columnname(datait, i)
                            _type = columntype(datait, i)
                            result = linter.correct_if(
                                        linter.f(_type, col, skipmissing(col), _name, code; linter_kwargs...)
                                     )
                            push!(lintout, (linter, "column: $_name") => result)
                        end
                    end
                    # 2. Apply over rows
                    if applicable(linter, :row, code)
                        irow = 1
                        no_empty_rows = true
                        for row in datait.row_iterator
                            result = linter.correct_if(
                                        linter.f(row, code; linter_kwargs...)
                                     )
                            if !isnothing(result) && !result  # skip trues or nothings as there may be too many
                                push!(lintout, (linter, "row: $irow") => result)
                                no_empty_rows = false
                            end
                            irow+= 1
                        end
                        # if there are no empty rows add a single entry, to mark the linter was applied and passed (true)
                        no_empty_rows && push!(lintout, (linter, "row: N/A") => true)
                    end
                    # 3. Apply over whole dataset
                    if applicable(linter, :dataset, code)
                        result = linter.correct_if(
                                    linter.f(datait.tblref, code; linter_kwargs...)
                                 )
                        push!(lintout, (linter, "dataset") => result)
                    end
            end;
            _, _time, _bytes, _gctime, _ = _t;
            @show linter.name, _time, _bytes, _gctime
        end
    end
    process_output(lintout; buffer, show_passing, show_stats, show_na)
    return lintout
end


function applicable(linter, iterable_type, code)
    if linter.name == :negative_values && iterable_type == :column && code !== nothing
        return true
    elseif linter.name == :many_missing_values && iterable_type == :column
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
