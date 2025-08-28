module KnowledgeBaseNative

using TOML
import ..KnowledgeBaseInterface:
    kb_load, kb_query,
    AbstractKnowledgeBase,
    build_linters,
    Linter

struct KnowledgeBase <: AbstractKnowledgeBase
    data::Dict
end

Base.show(io::IO, kb::KnowledgeBase) = begin
    mb_size = Base.summarysize(kb.data) / (1024^2)
    print(io, "KnowledgeBase with $mb_size MB of data")
end

function __load(filepath)
    data = try
        TOML.parse(open(filepath))
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

include("kb_native_linters.jl")

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


_LINTERS = Dict(
    "google" => [GOOGLE_LINTERS],
    "experimental" => [EXPERIMENTAL_LINTERS],
    "r" => [R_LINTERS],
    "all" => [GOOGLE_LINTERS, EXPERIMENTAL_LINTERS, R_LINTERS])

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
            correct_if = nt.correct_if,
            query = nt.query,
            query_match_type = if isnothing(nt.query)
                                    nothing
                               elseif hasfield(typeof(nt), :query_match_type)
                                    nt.query_match_type
                               else
                                    nothing
                               end,
            programming_language = nt.programming_language,
            requirements = nt.requirements)
end

end  # module
