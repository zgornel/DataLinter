@reexport module DataInterface
using Reexport
using Tables
import ..LinterCore: AbstractDataContext, DataIterator, build_data_iterator, context_code, columnname, columntype

# Main data interface function that abstracts over data contexts
export build_data_context


# Function that returns a DataStructure ammendable for use in the data linters.
# It contains a row iterator, a column iterator, metadata
build_data_iterator(tbl::Tables.Columns) = begin
    DataIterator(
                 column_iterator=Tables.columns(tbl),
                 row_iterator=Tables.rows(tbl),
                 tblref=Ref(tbl)
                )
end

build_data_iterator(data::AbstractVector) = begin
    build_data_iterator(Tables.Columns(Dict(Symbol("x$i")=>v for (i,v) in enumerate(data))))
end

build_data_iterator(ctx::AbstractDataContext) = build_data_iterator(ctx.data)

Base.show(io::IO, datait::DataIterator) = begin
    m, n = length(datait.row_iterator), length(datait.column_iterator)
    mb_size = Base.summarysize(datait.tblref)/(1024^2)
    print(io, "DataIterator over $m samples, $n variables, $mb_size MB of data")
end

function columnname(it::DataIterator, i::Int)
    return Tables.columnnames(it.column_iterator)[i]
end

function columntype(it::DataIterator, i::Int)
    name = columnname(it, i)
    return Tables.columntype(it.column_iterator, name)
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
    build_data_context(CSV.read(filepath, Tables.Columns))
end

end  # module
