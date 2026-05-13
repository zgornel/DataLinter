### CSV Related stuff
module DataCSV

using CSV
import ..DataInterface: build_data_context, CSVTypeTable, IOTypeTable

#Note: we assume the implicit interface for this bit `build_data_context`
#Note: in this case, the implementation re-uses the method
build_data_context(
    filepath::AbstractString,
    ::Union{Type{CSVTypeTable}, Type{IOTypeTable}};
    kwargs...
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(
        CSV.read(
            filepath, CSV.Tables.Columns;
            pool = true,                        # string pooling
            missingstring = ["", "NA", "NaN", "N/A", "NAN"],
            ignoreemptyrows = true,             # ignore empty rows
            ntasks = Threads.nthreads(),        # parallel parse
            kwargs...
        )
    )
end

build_data_context(
    filepath::AbstractString,
    code::AbstractString,
    ::Union{Type{CSVTypeTable}, Type{IOTypeTable}};
    kwargs...
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(
        CSV.read(
            filepath, CSV.Tables.Columns;
            pool = true,                        # string pooling
            missingstring = ["", "NA", "NaN", "N/A", "NAN"],
            ignoreemptyrows = true,             # ignore empty rows
            ntasks = Threads.nthreads(),        # parallel parse
            kwargs...
        ), code
    )
end

end  # module
