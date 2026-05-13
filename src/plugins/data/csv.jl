### CSV Related stuff
module DataCSV

using CSV
import ..DataInterface: build_data_context, CSVTypeTable, IOTypeTable

#Note: we assume the implicit interface for this bit `build_data_context`
#Note: in this case, the implementation re-uses the method

process_io(input_type::Type{CSVTypeTable}, input::AbstractString) = input
process_io(input_type::Type{IOTypeTable}, input::AbstractString) = seekstart(IOBuffer(input))

build_data_context(
    input::AbstractString,
    table_type::Union{Type{CSVTypeTable}, Type{IOTypeTable}};
    kwargs...
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(
        CSV.read(
            process_io(table_type, input),
            CSV.Tables.Columns;
            pool = true,                        # string pooling
            missingstring = ["", "NA", "NaN", "N/A", "NAN"],
            ignoreemptyrows = true,             # ignore empty rows
            ntasks = Threads.nthreads(),        # parallel parse
            kwargs...
        )
    )
end

build_data_context(
    input::AbstractString,
    code::AbstractString,
    table_type::Union{Type{CSVTypeTable}, Type{IOTypeTable}};
    kwargs...
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(
        CSV.read(
            process_io(table_type, input),
            CSV.Tables.Columns;
            pool = true,                        # string pooling
            missingstring = ["", "NA", "NaN", "N/A", "NAN"],
            ignoreemptyrows = true,             # ignore empty rows
            ntasks = Threads.nthreads(),        # parallel parse
            kwargs...
        ), code
    )
end

end  # module
