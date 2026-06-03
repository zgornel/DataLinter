### Arrow related stuff
module DataArrow

using Arrow
import ..DataInterface: build_data_context, ArrowTypeTable

build_data_context(
    filepath::AbstractString,
    ::Type{<:ArrowTypeTable};
    kwargs...
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(Arrow.Table(filepath))
end

build_data_context(
    filepath::AbstractString,
    code::AbstractString,
    ::Type{<:ArrowTypeTable};
    kwargs...
) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(Arrow.Table(filepath), code)
end

end  # module
