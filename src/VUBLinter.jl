#=
 The architecture for VUBLinter
 ------------------------------

 NOTE: This is living documentation and should be updated as the linter
       lives over time. Up to date as per commit: 01ad74d

  I. Dataflow diagram:
     ----------------
                                        .---------------.
       (knowledge) -------------------->|  KB INTERFACE |
                                        `---------------'
                                                 ^
                                                (3)
                                                 v
                  .----------------.        .---------.        .-----------------.
       (data) --> | DATA INTERFACE | -(1)-> | LINTER  | -(4)-> |OUTPUT INTERFACE | --> (output)
                  `----------------'        `---------'        `-----------------'
                       ^                         ^                   ^
       (config) -------'------(2)----------------'-------------------'


  II. Functional components:
      ---------------------
    • KB INTERFACE (`src/kb.jl`)
      `- handles communication with the knowledgebase
      `- at this point, has the data linters embedded in code (TODO: to be updated during dev)

    • DATA INTERFACE (`src/data.jl`)
      `- models types of 'data contexts' = data + metadata + information over where/when the data exists
         (i.e. a context could contain data and the snippet of code which is executed over the data)
      `- the 'context' defines how the linters (from the KB) are applied to the data

    • OUTPUT INTERFACE (`src/output.jl`)
      `- contains all sorts of printers and options to display data and statistics

    • LINTER (`src/linter.jl`)
      `- loop over linters×variables that applies each linter to variables/sets of variables
         (depending on context) and generates results


  III. Inputs and outputs:
       ------------------
    • data
      `-input data - at this point no external data is supported
      `- the internal representation supports `DataFrames.DataFrame`

    • config
      `-keeps configuration of the linter (TODO: to be updated during dev)

    • knowledge
      `- knowledge relevant for the functioning of the data linter
      `- currently all knowledge is present in `src/kb.jl` in the form of data structures and
         throughout the code as functions; this will change over time (TODO: to be updated during dev)

    • output
      `- what the user receives from the linter


  IV. Internal data transfer objects (DTOs):
      -------------------------------------
    • (1) - data context object i.e. data, data + code);
         `- this implies a unique data representation (values+semantics+context)
    • (2) - linter configuration information
    • (3) - knowledge i.e. linters, applicability conditions etc.
    • (4) - linting output i.e. linters/context, output, data stats etc.
=#
module VUBLinter

using Reexport

include("linter.jl")    # linter core
include("data.jl")      # data interface
include("output.jl")    # output interface
include("kb.jl")        # kb interface
include("workflows.jl") # workflows
include("precompilation.jl")  # precompilation

end # module VUBLinter
