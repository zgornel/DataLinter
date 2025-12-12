#/bin/sh
julia --startup-file=no --project=@runic -e 'using Pkg; Pkg.add("Runic")'
julia --startup-file=no --project=@runic -e 'using Runic; exit(Runic.main(ARGS))' -- --inplace src/ apps/ scripts/ test/ ipython/
