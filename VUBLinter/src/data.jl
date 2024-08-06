@reexport module DataInterface

using Reexport
import ..LinterCore: AbstractDataContext

# Data interface
function build_data_context end

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
