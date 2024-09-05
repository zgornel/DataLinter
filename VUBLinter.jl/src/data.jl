@reexport module DataInterface

using Reexport
using DataFrames
using Tables
import ..LinterCore: AbstractDataContext, DataIterator, build_data_iterator, context_code, columnname

# Main data interface function that abstracts over data contexts
export build_data_context


# Function that returns a DataStructure ammendable for use in the data linters.
# It contains a row iterator, a column iterator, metadata
build_data_iterator(df::DataFrame) = begin
     tbl = Tables.columntable(df)
     return DataIterator(
         column_iterator =((Tables.columntype(tbl, name),        # column eltype
                            getproperty(tbl, name),              # column values
                            skipmissing(getproperty(tbl, name)), # skipmissing on values
                            name,                                # column name
                           ) for name in Tables.columnnames(tbl)),
         row_iterator = Tables.rows(tbl),
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

function columnname(column)
    return last(column)
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


### CSV Related stuff (not yet another module/submodule)
using CSV

#Note: we assume the implicit interface for this bit `build_data_context`
build_data_context(filepath::AbstractString) = begin
    #TODO: make extension checks here and dispatch to specific
    #      file format handlers
    build_data_context(CSV.read(filepath, DataFrame))
end

end  # module
