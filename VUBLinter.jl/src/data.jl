@reexport module DataInterface

using Reexport
using DataFrames
using Tables
import ..LinterCore: AbstractDataContext, DataIterator, build_data_iterator, context_code

# Main data interface function that abstracts over data contexts
export build_data_context


# Function that returns a DataStructure ammendable for use in the data linters.
# It contains a row iterator, a column iterator, metadata
build_data_iterator(df::DataFrame) = begin
     coltype_dict = Dict(x["variable"]=>x["eltype"] for x in eachrow(describe(df)))
     return DataIterator(
         column_iterator = ((name, coltype_dict[name]) => vals for (name, vals) in pairs(eachcol(df))),
         #row_iterator = (collect(pairs(r)) for r in eachrow(df)),  # too slow
         row_iterator = Tables.rows(Tables.columntable(df)),
         coltype_iterator = (k=>v for (k,v) in coltype_dict),
         metadata = describe(df),
         dataref = Ref(df)
        )
end
build_data_iterator(data::Vector{<:Vector}) = build_data_iterator(DataFrame(data, :auto))
build_data_iterator(data::Vector{Any}) = build_data_iterator(DataFrame(data, :auto))
build_data_iterator(ctx::AbstractDataContext) = build_data_iterator(ctx.data)

Base.show(io::IO, datait::DataIterator) = begin
    m, n = size(datait.dataref[])
    mb_size = Base.summarysize(datait.dataref)/(1024^2)
    print(io, "DataIterator over $m samples, $n variables, $mb_size MB of data")
end


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
