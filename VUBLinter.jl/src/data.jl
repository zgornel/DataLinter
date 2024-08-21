@reexport module DataInterface

using Reexport
using DataFrames
import ..LinterCore: AbstractDataContext, variabilize, context_code

# Main data interface function that abstracts over data contexts
export build_data_context


# Transforms a context into an iterable of variables of form `Pair{name, values}`
__variabilize(data::DataFrame) = pairs(DataFrames.DataFrameColumns(data))
__variabilize(data::Vector{<:Vector}) = __variabilize(DataFrame(data, :auto))
__variabilize(data::Vector{Any}) = __variabilize(DataFrame(data, :auto))
function variabilize(ctx)
    return __variabilize(ctx.data)
end


# Simple data structure and its methods
Base.@kwdef struct SimpleDataContext <: AbstractDataContext
    elementwise=false
    data=nothing
end

Base.show(io::IO, ctx::SimpleDataContext) = begin
    mb_size = Base.summarysize(ctx.data)/(1024^2)
    print(io, "SimpleDataContext $mb_size MB of data")
end

build_data_context(data; elementwise=false) = SimpleDataContext(;data, elementwise)
context_code(ctx::SimpleDataContext) = nothing


# Simple data+code structure and its methods
Base.@kwdef struct SimpleCodeAndDataContext <: AbstractDataContext
    elementwise=false
    data=nothing
    code=nothing
end

Base.show(io::IO, ctx::SimpleCodeAndDataContext) = begin
    mb_size = (Base.summarysize(ctx.data) + Base.summarysize(ctx.code))/(1024^2)
    print(io, "SimpleCodeAndDataContext $mb_size MB of code+data")
end

build_data_context(data, code; elementwise=false) = SimpleCodeAndDataContext(;data, code, elementwise)
context_code(ctx::SimpleCodeAndDataContext) = ctx.code

end  # module
