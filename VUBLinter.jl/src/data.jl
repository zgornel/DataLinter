@reexport module DataInterface

using Reexport
using DataFrames
import ..LinterCore: AbstractDataContext, variabilize, get_code

# Data interface
function build_data_context end


function variabilize(ctx)
    return __variabilize(ctx.data)
end

__variabilize(data::DataFrame) = pairs(DataFrames.DataFrameColumns(data))
__variabilize(data::Vector{<:Vector}) = __variabilize(DataFrame(data, :auto))


@reexport module SimpleData

    import ..DataInterface: AbstractDataContext, build_data_context, get_code

    export SimpleDataContext, get_code


    Base.@kwdef struct SimpleDataContext <: AbstractDataContext
        elementwise=false
        data=nothing
    end

    Base.show(io::IO, ctx::SimpleDataContext) = begin
        mb_size = Base.summarysize(ctx.data)/(1024^2)
        print(io, "SimpleDataContext $mb_size MB of data")
    end


    function build_data_context(data; elementwise=false)
        return SimpleDataContext(;data, elementwise)
    end

    get_code(ctx::SimpleDataContext) = nothing

end  # module


@reexport module SimpleCodeAndData

    import ..DataInterface: AbstractDataContext, build_data_context, get_code

    export SimpleCodeAndDataContext, get_code


    Base.@kwdef struct SimpleCodeAndDataContext <: AbstractDataContext
        elementwise=false
        data=nothing
        code=nothing
    end

    Base.show(io::IO, ctx::SimpleCodeAndDataContext) = begin
        mb_size = (Base.summarysize(ctx.data) + Base.summarysize(ctx.code))/(1024^2)
        print(io, "SimpleCodeAndDataContext $mb_size MB of code+data")
    end


    function build_data_context(data, code; elementwise=false)
        return SimpleCodeAndDataContext(;data, code, elementwise)
    end

    get_code(ctx::SimpleCodeAndDataContext) = ctx.code
end  # module

end  # module
