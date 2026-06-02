@reexport module DataInterface
using Reexport
using Tables

import ..LinterCore: AbstractContext, DataIterator, build_data_iterator,
    get_context_code, get_context_data, columnname, columntype

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

build_data_iterator(::Nothing) = DataIterator{Nothing}(
    column_iterator = [],
    row_iterator = [],
    tblref = Ref(nothing)
)

build_data_iterator(ctx::AbstractContext) = build_data_iterator(get_context_data(ctx))

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

# Data+code context
Base.@kwdef struct CodeAndDataContext{T, S} <: AbstractContext
    data::T = nothing
    code::S = nothing
end

Base.show(io::IO, ctx::CodeAndDataContext{T}) where {T} = begin
    mb_size = (Base.summarysize(ctx.data) + Base.summarysize(ctx.code)) / (1024^2)
    print(io, "CodeAndDataContext{$T} ($mb_size MB of code+data)")
end

# Data-only context
Base.@kwdef struct DataContext{T} <: AbstractContext
    data::T = nothing
end

Base.show(io::IO, ctx::DataContext{T}) where {T} = begin
    mb_size = Base.summarysize(ctx.data) / (1024^2)
    print(io, "DataContext{$T} ($mb_size MB of data)")
end

# Code-only context
Base.@kwdef struct CodeContext{T} <: AbstractContext
    code::T = nothing
end

Base.show(io::IO, ctx::CodeContext{T}) where {T} = begin
    mb_size = Base.summarysize(ctx.code) / (1024)
    print(io, "CodeContext{$T} ($mb_size KB of code)")
end

# Local Table Types for plugin support
abstract type AbstractTypeTable end

struct CSVTypeTable <: AbstractTypeTable end

struct ArrowTypeTable <: AbstractTypeTable end

struct ParquetTypeTable <: AbstractTypeTable end

struct IOTypeTable <: AbstractTypeTable end


# Infers from an input string what data type we are dealing with
infer_datatype(::Nothing) = nothing

infer_datatype(data) = nothing

infer_datatype(data::AbstractString) = begin
    try
        if endswith(data, ".arrow")
            return ArrowTypeTable
        elseif endswith(data, ".csv") || endswith(data, "tsv")
            return CSVTypeTable
        elseif endswith(data, ".parquet")
            return ParquetTypeTable
        else
            # We assume data is a String that containts tabular data
            # This is useful for `datalinterserver` to be able to read
            # data from HTTP payloads
            return IOTypeTable
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
       ctx = DataLinter.build_data_context("./test/data/data.arrow")
DataContext{Arrow.Table} (0.11153507232666016 MB of data)

julia> kb = DataLinter.kb_load("");
       DataLinter.LinterCore.lint(ctx, kb)  # linters disabled
Pair{Tuple{DataLinter.LinterCore.Linter, String}, DataLinter.LinterCore.AbstractCheck}[]
Pair{Tuple{DataLinter.LinterCore.Linter, String}, DataLinter.LinterCore.AbstractCheck}[]


julia> config = DataLinter.LinterCore.load_config("./test/test_config.toml");
       DataLinter.LinterCore.lint(ctx, kb; config)  # linters enabled
120-element Vector{Pair{Tuple{DataLinter.LinterCore.Linter, String}, DataLinter.LinterCore.AbstractCheck}}:
                         (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x2") => DataLinter.LinterCore.NotAvailableCheck(nothing)
                         (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x5") => DataLinter.LinterCore.NotAvailableCheck(nothing)
                         (Linter (name=datetime_as_string, f=is_datetime_as_string), "column: x6") => DataLinter.LinterCore.PassedCheck(nothing)
                         ...
```
"""
function build_data_context(; data = nothing, code = nothing, kwargs...)
    datatype = infer_datatype(data)
    if isnothing(data)
        build_data_context(data, code; kwargs...)  # calls code-only method
    elseif isnothing(code)
        build_data_context(data, datatype; kwargs...)  # implemented in plugins
    else
        build_data_context(data, code, datatype; kwargs...)  # implemented in plugins
    end
end

# Code-only method
build_data_context(::Nothing, code; kwargs...) = CodeContext(; code)

# Generic methods, call kwarg-only `build_data_context`
build_data_context(data::AbstractString; kwargs...) = build_data_context(; data, kwargs...)
build_data_context(data::AbstractString, code; kwargs...) = build_data_context(; data, code, kwargs...)

# Specific methods, get called by plugin-implemented methods
build_data_context(data::T, code) where {T <: Tables.AbstractColumns} = CodeAndDataContext(; data, code)
build_data_context(data::T) where {T <: Tables.AbstractColumns} = DataContext(; data)

# Access context data
get_context_data(ctx::CodeAndDataContext) = ctx.data
get_context_data(ctx::DataContext) = ctx.data
get_context_data(ctx::CodeContext) = nothing

# Access context code
get_context_code(ctx::CodeAndDataContext) = ctx.code
get_context_code(ctx::DataContext) = nothing
get_context_code(ctx::CodeContext) = ctx.code

end  # module
