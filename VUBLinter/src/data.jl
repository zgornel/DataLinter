@reexport module DataInterface

using Reexport
using DataFrames
import ..LinterCore: AbstractDataContext, variabilize

# Data interface
function build_data_context end


function variabilize(ctx)
    return __variabilize(ctx.data)
end

__variabilize(data::DataFrame) = pairs(DataFrames.DataFrameColumns(data))
__variabilize(data::Vector{<:Vector}) = __variabilize(DataFrame(data, :auto))


@reexport module SimpleData

    import ..DataInterface: AbstractDataContext, build_data_context

    export SimpleDataContext


    Base.@kwdef struct SimpleDataContext <: AbstractDataContext
        elementwise=false
        data=nothing
    end

    Base.show(io::IO, ctx::SimpleDataContext) = begin
        mb_size = Base.summarysize(ctx.data)/(1024^2)
        print(io, "SimpleDataContext $mb_size MB of data, elementwise=$(ctx.elementwise)")
    end


    function build_data_context(;data=nothing, elementwise=false)
        return SimpleDataContext(;data, elementwise)
    end

end  # module


end  # module
