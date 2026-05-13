#=
oooooooodxOKWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMxoooooooOMMMMMMMMMd  :NMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
0o   .xxo:. .:0MMMMMMMMMMMMMMMMMMWKKMMMMMMMMMMMMMMMMKk.   d0XMMMMMMMMMd. ;NMMMMMMMMMMMMMMMMMMK0WMMMMMMMMMMMMMMMMMMMMMMMM
MO   ,MMMMNc   :NMMMMWNXXXWMMMMMX, .NWWMMMWNXXXNMMMMMW.   XMMMMMMMMMMWWNNWMMWWWWWMMNXXWMMMMWd  kWWMMMMNXXXWMMMWWWWWMMMNK
MO   ,MMMMMW,   dMM0.;lo:. 'kMNd.   clOMN';lo:  .xMMMW.   XMMMMMMMMMM0,  .XMO,  .do;   :NWk;   ;lkMNl'.:c..cNMO;  .kl.
MO   ,MMMMMM:   cMMXxNMMM:  .XMM,  .WMMMWkWMMMc  .NMMW.   XMMMMMMMMMMM:   KMMc  .NMMl   OMMd   OMMW;  ,MMc  ;WMd   ;xO0;
MO   ,MMMMMM;   oMWkc;;lo.  .XMM,  .WMMM0l;;lo'  .NMMW.   XMMMMMMMMMMM:   KMMc  .WMMo   OMMd   OMMX.  .lc;'':NMd   kMMMM
MO   ,MMMMMK.  'XMd   kMM:  .XMM,  .WMM0   lMMc  .NMMW.   XMMMMMMN,kMM:   KMMc  .WMMo   OMMd   OMMN.  ,MMMMMMMMd   kMMMM
Nx   .000kc  .dWMMx   lK0'  .KMM:   xKK0   ;00,  .XMWK.   kKKK00Oc 0MW:   0MW:  .NMMl   kMMO   c00Wk.  lO00OKMWo   xWMMM
'.........'ckWMMMMWo.  .:l...,XMXc.  .cMk.  .:o...;Xc.............'XMo....'Kl....cWO....'0MMx.   ;NMNl.   .;0Mo.....cNMM
---
   `- DataLinter, a code and data linter by Corneliu Cofaru, ©2026.
=#


#=
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
      - handles communication with the knowledge base
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
      - it is a self explanatory '.TOML' file
      - option names for linter parameters are also keyword argument names in the code

    • knowledge
      - code that implements the linters, found in the `knowledge/` directory
      - currently, in the form of data structures and functions

    • output
      - what the user receives from the linter

  IV. Internal data transfer objects (DTOs):
  -----------------------------------------
    • (1) - data context object i.e. data, data + code;
    • (2) - linter configuration information
    • (3) - knowledge i.e. linters, applicability conditions etc.
    • (4) - linting output i.e. linters/context, output, data stats etc.
=#


module DataLinter

using Reexport

include("linter.jl")    # linter core
include("config.jl")    # linter configuration

include("data.jl")      # data interface
include("plugins/data/csv.jl")  # CSV data plugin (CSV.jl)
include("plugins/data/arrow.jl")  # Apache Arrow data plugin (Arrow.jl)
include("plugins/data/parquet.jl")  # Parquet data plugin (Parquet.jl)

include("output.jl")    # output interface
include("kb.jl")        # kb interface
include("plugins/kb/native.jl")  # 'native kb' i.e. julia code plugin

include("workflows.jl") # workflows
include("version.jl")   # version
include("precompilation.jl")  # precompilation

end # module DataLinter
