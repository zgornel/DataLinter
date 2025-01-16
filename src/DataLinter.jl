"""
A data linter developed at the Vrije Universiteit Brussel, 2024.

  I. Architecture (dataflow diagram):
  ----------------------------------

```
                                        .---------------.
       (knowledge) -------------------->|  KB INTERFACE |
                                        '---------------'
                                                 ^
                                                (3)
                                                 v
                  .----------------.        .---------.        .-----------------.
       (data) --> | DATA INTERFACE | -(1)-> | LINTER  | -(4)-> |OUTPUT INTERFACE | --> (output)
                  '----------------'        '---------'        '-----------------'
                                                 ^
       (config) --------------(2)----------------'
```

  II. Functional components:
  -------------------------

    • KB INTERFACE (`src/kb*.jl`)
      - handles communication with the knowledgebase
      Note: at this point the knowledge i.e. the data linters, is embedded in code

    • DATA INTERFACE (`src/data.jl`)
      - models types of 'data contexts' = 'data' + 'metadata' + 'information' over where/when the data exists
         (i.e. a context could contain data and the snippet of code which is executed over the data)
      - the 'context' contributes as well to how/which linters are applied to the data

    • OUTPUT INTERFACE (`src/output.jl`)
      - contains all code related to exporting or printing linting output and displaying statistics

    • LINTER (`src/linter.jl`)
      - functional core of the system
      - it is a loop over linters × variables that applies each linter to variables/sets of variables
        (depending on context) and generates results

  III. Inputs and outputs:
  -----------------------

    • data
      - at this point only '.CSV' files are supported
      - the internal representation supports the `Tables` interface

    • config
      - keeps configuration of the linter
      - should be self explanatory '.TOML' file
      - option names for linter parameters are also keyword argument names in the code

    • knowledge
      - knowledge relevant for the functioning of the data linter
      - currently all knowledge is present in `src/kb*.jl` in the form of data structures and
        throughout the code as functions
        Note: this will change over time

    • output
      - what the user receives from the linter

  IV. Internal data transfer objects (DTOs):
  -----------------------------------------
    • (1) - data context object i.e. data, data + code;
    • (2) - linter configuration information
    • (3) - knowledge i.e. linters, applicability conditions etc.
    • (4) - linting output i.e. linters/context, output, data stats etc.
"""
module DataLinter

using Reexport

include("linter.jl")    # linter core
include("config.jl")    # linter configuration

include("data.jl")      # data interface
  include("plugins/csv.jl")  # 'csv data' plugin

include("output.jl")    # output interface
include("kb.jl")        # kb interface
  include("plugins/kb_native.jl")  # 'native kb' plugin

include("workflows.jl") # workflows
include("version.jl")   # version
include("precompilation.jl")  # precompilation

end # module DataLinter
