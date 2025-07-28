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

function build_linters(kb, ctx; linters = ["all"])
    #TODO: Implement query of the knowledge base
    #      based on the context provided i.e.
    #      use `kb_query` to get data, wrap it etc.
    #      and return it (to `LinterCore`)
    nts = []
    if "all" in linters
        nts = vcat(nts, GOOGLE_LINTERS, EXPERIMENTAL_LINTERS)
    else
        if "google" in linters
            nts = vcat(nts, GOOGLE_LINTERS)
        end
        if "experimental" in linters
            nts = vcat(nts, EXPERIMENTAL_LINTERS)
        end
    end
    return [Linter(nt...) for nt in nts]
end
end  # module
