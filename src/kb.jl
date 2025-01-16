@reexport module KnowledgeBaseInterface

using Reexport
import ..LinterCore: AbstractKnowledgeBase, build_linters, Linter
export kb_load, kb_query

"""
Loads a knowledge base.
"""
function kb_load end

"""
Runs a query over a knowledge base.
"""
function kb_query end


end  # module
