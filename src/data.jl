@reexport module DataInterface
using Reexport
using Tables
import ..LinterCore: AbstractDataContext, DataIterator, build_data_iterator,
                     get_context_code, columnname, columntype

# Main data interface function that abstracts over data contexts
export build_data_context

"""
Function that returns a DataStructure ammendable for use in the data linters.
It contains a row iterator, a column iterator, metadata
"""
build_data_iterator(tbl::Tables.Columns) = begin
    DataIterator(
                 column_iterator=Tables.columns(tbl),
                 row_iterator=Tables.rows(tbl),
                 tblref=Ref(tbl)
                )
end

build_data_iterator(data::Dict{Symbol, <:AbstractVector}) = begin
    build_data_iterator(Tables.Columns(data))
end

build_data_iterator(data::AbstractVector) = begin
    build_data_iterator(Dict(Symbol("x$i")=>v for (i,v) in enumerate(data)))
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

# Simple data+code structure and its methods
Base.@kwdef struct SimpleCodeAndDataContext <: AbstractDataContext
    data=nothing
    code=nothing
end

Base.show(io::IO, ctx::SimpleCodeAndDataContext) = begin
    mb_size = (Base.summarysize(ctx.data) + Base.summarysize(ctx.code))/(1024^2)
    print(io, "SimpleCodeAndDataContext $mb_size MB of code+data")
end


"""
    build_data_context(;data=nothing, code=nothing)

Builds a data context object using `data` and `code` if available. The
data context represents a context in which the linter runs: the data
it lints and optionally, the `code` associated to the `data` i.e. some
algorithm that will be applied on that data.

# Examples
```julia
julia> using DataLinter
       ncols, nrows = 3, 10
       data = [rand(nrows) for _ in 1:ncols]
       ctx = DataLinter.build_data_context(data)
SimpleDataContext 0.00040435791015625 MB of data

julia> kb = DataLinter.kb_load("")
       DataLinter.LinterCore.lint(ctx, kb)
38-element Vector{Pair{Tuple{DataLinter.LinterCore.Linter, String}, Union{Nothing, Bool}}}:
         (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x2") => nothing
         (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x3") => nothing
         (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x1") => nothing
         (Linter (name=tokenizable_string, f=is_tokenizable_string), "column: x2") => nothing
         ...
```
"""
function build_data_context(;data=nothing, code=nothing)
    if isnothing(data)
        @error "Missing data"
    elseif isnothing(code)
        build_data_context(data)
    else
        build_data_context(data, code)
    end
end


build_data_context(data) = SimpleDataContext(;data)
build_data_context(data, code) = SimpleCodeAndDataContext(;data, code)

get_context_code(ctx::SimpleCodeAndDataContext) = ctx.code
get_context_code(ctx::SimpleDataContext) = nothing

end  # module
