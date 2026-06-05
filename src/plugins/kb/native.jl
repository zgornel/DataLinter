module KnowledgeBaseNative

using TOML
using Dates
using Statistics
using LinearAlgebra
using StatsBase
using Distributions
using HypothesisTests
using Tables
using ParSitter

import ..KnowledgeBaseInterface:
    kb_load, kb_query,
    AbstractKnowledgeBase,
    build_linters,
    Linter,
    AbstractCheck,
    PassedCheck,
    FailedCheck,
    NotAvailableCheck

# Meta-types for varius column element types
NumericEltype = Union{<:Number, Union{Missing, <:Number}}
FloatEltype = Union{<:AbstractFloat, Union{Missing, <:AbstractFloat}}
StringEltype = Union{<:AbstractString, Union{Missing, <:AbstractString}}
TimeEltype = Union{<:Dates.AbstractTime, Union{Missing, <:Dates.AbstractTime}}
ListEltype = Union{Any, Vector{Any}}

include("rformula.jl")

# Load linters code
const NATIVE_KB_DIR = joinpath(
    dirname(abspath(@__FILE__)),
    "..", "..", "..", "knowledge", "native"
)
for (root, _, files) in walkdir(NATIVE_KB_DIR)
    for file in files
        full_file = joinpath(NATIVE_KB_DIR, file)
        include(full_file)
        @debug "Included KB Native file @$full_file"
    end
end

_LINTERS = Dict(
    "google" => [GOOGLE_BASELINE_LINTERS],
    "extended" => [EXTENDED_BASELINE_LINTERS],
    "r" => [R_BASELINE_LINTERS],
    "all" => [GOOGLE_BASELINE_LINTERS, EXTENDED_BASELINE_LINTERS, R_BASELINE_LINTERS]
)


# Print large iterables up to a certain length of characters
function process_for_printing(iterable; joinchar = ", ", maxlen = 50)
    output = join(string.(iterable), joinchar)
    if length(output) > maxlen
        output = output[1:maxlen] * "..."
    end
    return output
end

struct KnowledgeBase <: AbstractKnowledgeBase
    data::Dict
end

Base.show(io::IO, kb::KnowledgeBase) = begin
    mb_size = Base.summarysize(kb.data) / (1024^2)
    print(io, "KnowledgeBase with $mb_size MB of data")
end

function __load(filepath)
    data = try
        open(filepath, "r") do io
            TOML.parse(io)
        end
    catch
        @debug "Could not load KB@$filepath. Returning empty Dict()."
        Dict{String, String}()
    end
    return data
end

# TODO: Implement functionality for query/retrieval of knowledge
function __query(::KnowledgeBase, query)
    return @error "KB query is not implemented"
end

# Actual implementation of the Interface
"""
    kb_load(filepath::String)

Loads a Knowledge Base file located at `filepath`.
The loaded knowledge is used by the `lint` function
to drive the linting.

# Examples
```julia
julia> using DataLinter
julia> using TOML

julia> data = Dict("a"=>1)
julia> mktemp() do kbpath, io
           TOML.print(io, data)   # write data
           flush(io);             # and flush to disk
           kb = kb_load(kbpath);  # load data with `kb_load`
           kb.data                # return loaded data
       end
Dict{String, Any} with 1 entry:
  "a" => 1
```
"""
function kb_load(filepath::String)
    return KnowledgeBase(__load(filepath))
end

function kb_query(kb::KnowledgeBase, query::String)
    return __query(kb.data, query)
end

function build_linters(kb, ctx; linters = ["all"])
    #TODO: Implement query of the knowledge base
    #      based on the context provided i.e.
    #      use `kb_query` to get data, wrap it etc.
    #      and return it (to `LinterCore`)
    nts = []
    lnts = intersect(unique(linters), keys(_LINTERS))
    if "all" in lnts
        nts = vcat(_LINTERS["all"]...)
    else
        for l in lnts
            append!(nts, _LINTERS[l]...)
        end
    end
    return [_namedtuple_to_linter(nt) for nt in nts]
end

function _namedtuple_to_linter(nt)
    return Linter(
        name = nt.name,
        description = nt.description,
        f = nt.f,
        failure_message = nt.failure_message,
        correct_message = nt.correct_message,
        warn_level = nt.warn_level,
        query = nt.query,
        query_match_type = if isnothing(nt.query)
            nothing
        elseif hasfield(typeof(nt), :query_match_type)
            nt.query_match_type
        else
            nothing
        end,
        programming_language = nt.programming_language,
        requirements = nt.requirements
    )
end

end  # module
