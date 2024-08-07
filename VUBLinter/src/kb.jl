@reexport module KnowledgeBaseInterface

using Reexport
import ..LinterCore: AbstractKnowledgeBase, get_rules
export kb_load, kb_query

# KB interface
function kb_load end
function kb_query end

# TODO: remove this utility function later
function kb_load(filepath::String)
    KnowledgeBaseJulia.kb_load(KnowledgeBaseNative, filepath)
end

function get_rules(kb, ctx)
    __get_rules_stump()
end


function __get_rules_stump()
    #TODO: Extend this
    [(name = :no_missing_values,
      description = """ Tests that no missing values exist in variable """,
      f = (v, code=nothing) -> all(.!ismissing.(v)) && all(.!isnothing.(v)),
      message = name->"M01 - Found missing values in variable '$name' (HIGH)",
      correct_if = true
      ),
     (name = :no_negative_values,
      description = """ Tests that no negative values exist in variable """,
      f = (v, code=nothing) -> begin
        if code==nothing
            return all(Iterators.map(>=(0), (Iterators.filter(!ismissing, v))))
        else
            return true  # if we have code, we don't care about the rule
        end
      end,
      message = name->"M02 - Found values smaller than 0 in variable '$name' (LOW)",
      correct_if = true
     )
     ]
end



@reexport module KnowledgeBaseJulia

    using TOML
    import ..KnowledgeBaseInterface: AbstractKnowledgeBase, kb_load, kb_query

    export KnowledgeBaseNative


    struct KnowledgeBaseNative <: AbstractKnowledgeBase
        data::Dict
    end

    Base.show(io::IO, kb::KnowledgeBaseNative) = begin
        mb_size = Base.summarysize(kb.data)/(1024^2)
        print(io, "KnowledgeBase (native), $mb_size MB of data")
    end



    function kb_load(::Type{KnowledgeBaseNative}, filepath)
        KnowledgeBaseNative(TOML.parse(open(filepath)))
    end

    function kb_query(::Type{KnowledgeBaseNative}, query)
        @error "KB query is not implemented"
    end

end  # module



end  # module
