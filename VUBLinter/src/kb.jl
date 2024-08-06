@reexport module KnowledgeBaseInterface

using Reexport
import ..LinterCore: AbstractKnowledgeBase
export kb_load, kb_query

# KB interface
function kb_load end
function kb_query end

# TODO: remove this utility function later
function kb_load(filepath::String)
    KnowledgeBaseJulia.kb_load(KnowledgeBaseNative, filepath)
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
