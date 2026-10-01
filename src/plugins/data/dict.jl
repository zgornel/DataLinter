# Generic Dict or JSON-parsable to Dict data; this is the case when linters require multiple variables, such
# as in the case of Python linters where data and targets are usually distict.
module DataGenericDict

using CSV, JSON
import ..DataInterface: build_data_context, IOTypeDict

# Specialized CSV parsing function
function csv_parse_function(input; kwargs...)
    return CSV.read(
        seekstart(IOBuffer(input)),
        CSV.Tables.Columns;
        pool = true,                        # string pooling
        missingstring = ["", "NA", "NaN", "N/A", "NAN"],
        ignoreemptyrows = true,             # ignore empty rows
        ntasks = Threads.nthreads(),        # parallel parse
        kwargs...
    )
end

# Method for actual Dict data inputs
build_data_context(
    data_dict::JSON.Object,
    kwargs...
) = begin
    object_dict = Dict(
        try
                k => csv_parse_function(v; kwargs...)
        catch
                @debug "Dict data plugin: could not parse key=\"$k\" as csv."
                k => nothing
        end
            for (k, v) in data_dict
    )
    filter!(p -> !isnothing(p.second), object_dict)  # filter out keysd not parsed as CSV
    return build_data_context(object_dict)  # calls method from DataInterface
end

# Method for JSON-like data inputs
build_data_context(
    input::AbstractString,
    table_type::Type{IOTypeDict};
    kwargs...
) = begin
        data_dict = JSON.parse(input)
        return build_data_context(data_dict; kwargs...)  # calls JSON.Object method above
end

# Method for actual Dict data inputs with code
build_data_context(
    data_dict::JSON.Object,
    code::AbstractString;
    kwargs...
) = begin
    object_dict = Dict(
        try
                k => csv_parse_function(v; kwargs...)
        catch
                @debug "Dict data plugin: could not parse key=\"$k\" as csv."
                k => nothing
        end
            for (k, v) in data_dict
    )
    filter!(p -> !isnothing(p.second), object_dict)  # filter out keys not parsed as CSV
    return build_data_context(object_dict, code)  # calls method from DataInterface
end

# Method for JSON-like data inputs with code
build_data_context(
    input::AbstractString,
    code::AbstractString,
    table_type::Type{IOTypeDict};
    kwargs...
) = begin
    data_dict = JSON.parse(input)
    return build_data_context(data_dict, code; kwargs...)  # Calls JSON.Object method above
end


end  # module
