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
        KnowledgeBase(TOML.parse(open(filepath)))
    end

    # TODO: Implement functionality for query/retrieval of knowledge
    function query(::KnowledgeBase, query)
        @error "KB query is not implemented"
    end

    #####
    #TODO: Extend this:
    #      - by adding more content: rules (and contexts) etc.
    #      - an external data structure
    #      - something loadable into a `KnowledgeBase` object
    #
    const DATA_LINTING_RULES = begin
        [(name = :no_missing_values,
          description = """ Tests that no missing values exist in variable """,
          f = (v, code=nothing) -> all(.!ismissing.(v)) && all(.!isnothing.(v)),
          failure_message = name->"found missing values in variable '$name'",
          correct_message = name->"no missing values in variable '$name'",
          warn_level = "warning",
          correct_if = true
          ),
         (name = :no_negative_values,
          description = """ Tests that no negative values exist in variable """,
          f = (v, code=nothing) -> all(Iterators.map(>=(0), (Iterators.filter(!ismissing, v)))),
          failure_message = name->"found values smaller than 0 in variable '$name'",
          correct_message = name->"no values smaller than 0 in variable '$name'",
          warn_level = "info",
          correct_if = true
         )
         ]
    end


end  # module



# The interface module `KnowledgeBaseInterface` depends both on
# `LinterCore` and `KnowledgeBaseNative` as neither of these
# modules should know of each other:
#  - `LinterCore` exposes the abstract types and top methods
#  - `KnowledgeBaseNative` implements a KB
@reexport module KnowledgeBaseInterface

using Reexport
import ..LinterCore: AbstractKnowledgeBase, get_rules
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

function kb_load(filepath::String)
    KnowledgeBaseWrapper(KnowledgeBaseNative.load(filepath))
end

function kb_query(kb::KnowledgeBaseWrapper, query::String)
    KnowledgeBaseNative.query(kb.data, query)
end


function get_rules(kb, ctx)
    #TODO: Implement query of the knowledge base
    #      based on the context provided i.e.
    #      use `kb_query` to get data, wrap it etc.
    #      and return it (to `LinterCore`)
    return KnowledgeBaseNative.DATA_LINTING_RULES
end

end  # module
