# Minimal implementation (stump) of a Knowledge Base
# This is a placeholder for, ideally a full implementation
# of a knowledge graph
module KnowledgeBaseNative

    using TOML
    export KnowledgeBase, load, query

    struct KnowledgeBase
        data::Dict
    end

    Base.show(io::IO, kb::KnowledgeBase) = begin
        mb_size = Base.summarysize(kb.data)/(1024^2)
        print(io, "KnowledgeBase with $mb_size MB of data")
    end

    function load(filepath)
        data = try
            TOML.parse(open(filepath))
        catch
            @debug "Could not load KB@$filepath. Returning empty Dict()."
            Dict{String, String}()
        end
        return KnowledgeBase(data)
    end

    # TODO: Implement functionality for query/retrieval of knowledge
    function query(::KnowledgeBase, query)
        @error "KB query is not implemented"
    end

    include("kb_linters_code.jl")


end  # module



# The interface module `KnowledgeBaseInterface` depends both on
# `LinterCore` and `KnowledgeBaseNative` as neither of these
# modules should know of each other:
#  - `LinterCore` exposes the abstract types and top methods
#  - `KnowledgeBaseNative` implements a KB
@reexport module KnowledgeBaseInterface

using Reexport
import ..LinterCore: AbstractKnowledgeBase, build_linters, Linter
import ..KnowledgeBaseNative
export kb_load

# Abstraction over loading data from KB
function kb_load end
# Abstraction over querying KB for data
function kb_query end


struct KnowledgeBaseWrapper <: AbstractKnowledgeBase
    data::KnowledgeBaseNative.KnowledgeBase
end

Base.show(io::IO, kb::KnowledgeBaseWrapper) = begin
    print(io, "KnowledgeBaseWrapper, data: $(kb.data)")
end

"""
    kb_load(filepath::String)

Loads a Knowledge Base file located at `filepath`.
The loaded knowledge is used by the [`lint`](@ref) function
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
           kb.data.data           # return loaded data
       end
Dict{String, Any} with 1 entry:
  "a" => 1
```
"""
function kb_load(filepath::String)
    KnowledgeBaseWrapper(KnowledgeBaseNative.load(filepath))
end

function kb_query(kb::KnowledgeBaseWrapper, query::String)
    KnowledgeBaseNative.query(kb.data, query)
end


function build_linters(kb, ctx)
    #TODO: Implement query of the knowledge base
    #      based on the context provided i.e.
    #      use `kb_query` to get data, wrap it etc.
    #      and return it (to `LinterCore`)
    linters = [Linter(nt...) for nt in vcat(KnowledgeBaseNative.GOOGLE_DATA_LINTERS,
                                            KnowledgeBaseNative.ADDITIONAL_DATA_LINTERS)
              ]
    return linters
end

end  # module
