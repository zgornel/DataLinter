### Parquet related stuff
module DataParquet

using Parquet
import ..DataInterface: build_data_context, ParquetTypeTable

build_data_context(
    filepath::AbstractString,
    ::Type{<:ParquetTypeTable};
    kwargs...
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(Parquet.read_parquet(filepath))
end

build_data_context(
    filepath::AbstractString,
    code::AbstractString,
    ::Type{<:ParquetTypeTable};
    kwargs...
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(Parquet.read_parquet(filepath), code)
end

end  # module
