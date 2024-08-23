@reexport module DataInterface

using Reexport
using DataFrames
import ..LinterCore: AbstractDataContext, data_iterables, context_code

# Main data interface function that abstracts over data contexts
export build_data_context, DataStructure


### # TODO: See if makes sense to use this (as return type from `data_iterables`)
### @Base.kwargs struct LinterDataIterator
###     column_iterator
###     row_iterator
###     coltype_iterator
###     metadata
### end

# Function that returns a DataStructure ammendable for use in the data linters.
# It contains a row iterator, a column iterator, metadata
data_iterables(df::DataFrame) = begin
     coltype_dict = Dict(x["variable"]=>x["eltype"] for x in eachrow(describe(df)))
     return (
         # Iterator over columns, each element is a Pair{Symbol, Vector} like :x1 => [x1₁, x1₂, ..., x1ₙ]
         column_iterator = ((name, coltype_dict[name]) => vals for (name, vals) in pairs(eachcol(df))),

         # Iterator over rows, each element is a Vector{Pair} [:x1=>x1ᵢ, :x2=>x2ᵢ, ..., :xm=>xmᵢ]
         row_iterator = (collect(pairs(r)) for r in eachrow(df)),

         # Iterator over column types, each element is a Pair{Symbol, DataType} like :x1=>Float64
         coltype_iterator = Iterators.map(x->x["variable"]=>x["eltype"], eachrow(describe(df))),

         metadata = describe(df),

         dataref = Ref(df)
        )
end
data_iterables(data::Vector{<:Vector}) = data_iterables(DataFrame(data, :auto))
data_iterables(data::Vector{Any}) = data_iterables(DataFrame(data, :auto))
data_iterables(ctx::AbstractDataContext) = data_iterables(ctx.data)


# Simple data structure and its methods
Base.@kwdef struct SimpleDataContext <: AbstractDataContext
    data=nothing
end

Base.show(io::IO, ctx::SimpleDataContext) = begin
    mb_size = Base.summarysize(ctx.data)/(1024^2)
    print(io, "SimpleDataContext $mb_size MB of data")
end

build_data_context(data) = SimpleDataContext(;data)
context_code(ctx::SimpleDataContext) = nothing


# Simple data+code structure and its methods
Base.@kwdef struct SimpleCodeAndDataContext <: AbstractDataContext
    data=nothing
    code=nothing
end

Base.show(io::IO, ctx::SimpleCodeAndDataContext) = begin
    mb_size = (Base.summarysize(ctx.data) + Base.summarysize(ctx.code))/(1024^2)
    print(io, "SimpleCodeAndDataContext $mb_size MB of code+data")
end

build_data_context(data, code) = SimpleCodeAndDataContext(;data, code)
context_code(ctx::SimpleCodeAndDataContext) = ctx.code

end  # module
