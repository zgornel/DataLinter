# Generic Dict data; this is the case when linters require multiple variables, such
# as in the case of Python linters where data and targets are usually distict.
module DataGenericDict

using CSV, JSON
import ..DataInterface: build_data_context, IOTypeDict

#Note: we assume the implicit interface for this bit `build_data_context`
#Note: in this case, the implementation re-uses the method

process_io(input_type::Type{IOTypeDict}, input::AbstractString) = seekstart(IOBuffer(input))

function csv_parse_function(table_type, input; kwargs...)
    return CSV.read(
        process_io(table_type, input),
        CSV.Tables.Columns;
        pool = true,                        # string pooling
        missingstring = ["", "NA", "NaN", "N/A", "NAN"],
        ignoreemptyrows = true,             # ignore empty rows
        ntasks = Threads.nthreads(),        # parallel parse
        kwargs...
    )
end

build_data_context(
    input::AbstractString,
    table_type::Type{IOTypeDict};
    kwargs...
) = begin
    data_dict = JSON.parse(input)
    object_dict = Dict(
        k => csv_parse_function(table_type, v; kwargs...)
            for (k, v) in data_dict
    )
    return build_data_context(object_dict)
end

build_data_context(
    input::AbstractString,
    code::AbstractString,
    table_type::Type{IOTypeDict};
    kwargs...
) = begin
    data_dict = JSON.parse(input)
    object_dict = Dict(
        k => csv_parse_function(table_type, v; kwargs...)
            for (k, v) in data_dict
    )
    return build_data_context(object_dict, code)
end

end  # module
