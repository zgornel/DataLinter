#/bin/sh
julia --project=@runic -e 'using Pkg; Pkg.add("Runic")'       
julia --project=@runic -e 'using Runic; exit(Runic.main(ARGS))' -- --inplace src/ apps/ scripts/ test/
