### CSV Related stuff
module DataCSV

using CSV
import ..DataInterface: build_data_context, CSVTypeTable

#Note: we assume the implicit interface for this bit `build_data_context`
#Note: in this case, the implementation re-uses the method
build_data_context(
    filepath::AbstractString,
    ::Type{CSVTypeTable}
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(
        CSV.read(
            filepath, CSV.Tables.Columns;
            pool = true,                        # string pooling
            missingstring = ["", "NA", "NaN", "N/A", "NAN"],
            ignoreemptyrows = true,             # ignore empty rows
            ntasks = Threads.nthreads()         # parallel parse
        )
    )
end

build_data_context(
    filepath::AbstractString,
    code::AbstractString,
    ::Type{CSVTypeTable}
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(
        CSV.read(
            filepath, CSV.Tables.Columns;
            pool = true,                        # string pooling
            missingstring = ["", "NA", "NaN", "N/A", "NAN"],
            ignoreemptyrows = true,             # ignore empty rows
            ntasks = Threads.nthreads()         # parallel parse
        ), code
    )
end

end  # module
