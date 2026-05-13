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
build_data_iterator(tbl::T) where {T <: Tables.AbstractColumns} = begin
    DataIterator{T}(
        column_iterator = Tables.columns(tbl),
        row_iterator = Tables.rows(tbl),
        tblref = Ref(tbl)
    )
end

build_data_iterator(data::Dict{Symbol, <:AbstractVector}) = begin
    build_data_iterator(Tables.Columns(data))
end

build_data_iterator(data::AbstractVector) = begin
    build_data_iterator(Dict(Symbol("x$i") => v for (i, v) in enumerate(data)))
end

build_data_iterator(ctx::AbstractDataContext) = build_data_iterator(ctx.data)

Base.show(io::IO, datait::DataIterator{T}) where {T} = begin
    m, n = length(datait.row_iterator), length(datait.column_iterator)
    mb_size = Base.summarysize(datait.tblref) / (1024^2)
    print(io, "DataIterator{$T} ($m samples, $n variables, $mb_size MB of data)")
end

function columnname(it::DataIterator, i::Int)
    return Tables.columnnames(it.column_iterator)[i]
end

function columntype(it::DataIterator, i::Int)
    name = columnname(it, i)
    return Tables.columntype(it.column_iterator, name)
end


# Simple data structure and its methods
Base.@kwdef struct SimpleDataContext{T} <: AbstractDataContext
    data::T = nothing
end

Base.show(io::IO, ctx::SimpleDataContext{T}) where {T} = begin
    mb_size = Base.summarysize(ctx.data) / (1024^2)
    print(io, "SimpleDataContext{$T} ($mb_size MB of data)")
end

# Simple data+code structure and its methods
Base.@kwdef struct SimpleCodeAndDataContext{T, S} <: AbstractDataContext
    data::T = nothing
    code::S = nothing
end

Base.show(io::IO, ctx::SimpleCodeAndDataContext{T}) where {T} = begin
    mb_size = (Base.summarysize(ctx.data) + Base.summarysize(ctx.code)) / (1024^2)
    print(io, "SimpleCodeAndDataContext{$T} ($mb_size MB of code+data)")
end


# Local Table Types for plugin support
abstract type AbstractTypeTable end

struct CSVTypeTable <: AbstractTypeTable end

struct ArrowTypeTable <: AbstractTypeTable end

struct ParquetTypeTable <: AbstractTypeTable end

# Generic methods (need to be overloaded in plugins)
infer_datatype(::Nothing) = nothing
infer_datatype(data) = nothing

infer_datatype(filepath::AbstractString) = begin
    try
        if endswith(filepath, ".arrow")
            return ArrowTypeTable
        elseif endswith(filepath, ".csv") || endswith(filepath, "tsv")
            return CSVTypeTable
        elseif endswith(filepath, ".parquet")
            return ParquetTypeTable
        end
        return nothing
    catch e
        @debug "Could not infer datatype, this will cause and exit...\n$e"
        nothing
    end
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
       DataLinter.LinterCore.lint(ctx, kb)  # linters disabled
Pair{Tuple{DataLinter.LinterCore.Linter, String}, DataLinter.LinterCore.AbstractCheck}[]

julia> config = DataLinter.LinterCore.load_config("./test/test_config.toml")
       DataLinter.LinterCore.lint(ctx, kb; config)  # linters enabled
49-element Vector{Pair{Tuple{DataLinter.LinterCore.Linter, String}, DataLinter.LinterCore.AbstractCheck}}:
                     (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x2") => DataLinter.LinterCore.NotAvailableCheck(nothing)
                     (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x3") => DataLinter.LinterCore.NotAvailableCheck(nothing)
                     (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x1") => DataLinter.LinterCore.NotAvailableCheck(nothing)
                     ...
```
"""
function build_data_context(; data = nothing, code = nothing)
    datatype = infer_datatype(data)
    if isnothing(datatype)
        throw(ErrorException("Could not infer data type. Make sure data type is supported."))
    end
    if isnothing(code)
        build_data_context(data, datatype)
    else
        build_data_context(data, code, datatype)
    end
end


# Generic methods (need to be overloaded in plugins)
build_data_context(data::AbstractString) = build_data_context(; data)
build_data_context(data::AbstractString, code) = build_data_context(; data, code)

# Specific methods, get called by plugin-implemented methods
build_data_context(data::T) where {T <: Tables.AbstractColumns} = SimpleDataContext(; data)
build_data_context(data::T, code) where {T <: Tables.AbstractColumns} = SimpleCodeAndDataContext(; data, code)

get_context_code(ctx::SimpleCodeAndDataContext) = ctx.code
get_context_code(ctx::SimpleDataContext) = nothing

end  # module
