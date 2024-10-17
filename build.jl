#!/usr/bin/julia

using TOML

# This file must be ran inside the build/ directory of the project. It is assumed that
# the upper directory i.e. ../ is the main project directory where the Project.toml and
# Manifest.toml files reside.
const PROJECT_NAME = "DataLinter"
const PROJECT_DIR = dirname(@__FILE__)                                    # root project directory
const BASE_ENV_PATH = joinpath(ENV["HOME"], ".julia", "environments",
                               "v" * string(Int(Base.VERSION.major)) * "." *
                                     string(Int(Base.VERSION.minor))
                              )
const APPS_PATH = abspath(joinpath(PROJECT_DIR, "apps"))
const COMPILED_PATH = abspath(joinpath(PROJECT_DIR, "build"))           # build directory
const TARGETS = readdir(APPS_PATH)                                      # file(s) to be compiled
const TARGETS_PATHS = abspath.(joinpath.(APPS_PATH, TARGETS))           # full path to the targes
const REQUIRED_PACKAGES = ["PackageCompiler"]                           # required packages for compilation
const PACKAGE_REVS = Dict(                                              # Packag revisions/branches/etc
    #"PackageCompiler"=>("https://github.com/JuliaLang/PackageCompiler.jl", "master"),
   )
const CPU_TARGET = "generic"
const PRECOMPILE_JL = "precompile.jl"                                   # File which contains code from which precompilation statements should be recorded
const PRECOMPILE_FILES = map(Base.Fix2(joinpath, PRECOMPILE_JL), TARGETS_PATHS)

##############
### Checks ###
##############

# Check that the upper directory has a Project.toml and the project is DataLinter
project_file = joinpath(PROJECT_DIR, "Project.toml")
if isfile(project_file)
    key_name = "name"
    project_name = try
        get(TOML.parsefile(project_file), key_name, "")
    catch
        printstyled("× Something went wrong while retrieving project name from $project_file. Exiting...\n", color=:red, bold=true)
        exit()
    end
    if project_name != PROJECT_NAME
        printstyled("× Malformed project name in Project.toml (expected: name=$PROJECT_NAME). Exiting...\n", color=:red, bold=true)
        exit()
    end
else
    printstyled("× $project_file for $PROJECT_NAME does not exist. Exiting...\n", color=:red, bold=true)
    exit()
end

# Check for a manifest file, warn if not present
manifest_file = joinpath(PROJECT_DIR, "Manifest.toml")
if !isfile(manifest_file)
    printstyled("! $manifest_file for $PROJECT_NAME does not exist. Will continue...\n", color=:yellow)
end

printstyled("• Pre-checks complete.\n", bold=true)

# Build or cleanup directory
if !isdir(COMPILED_PATH)
    mkdir(COMPILED_PATH)
    printstyled("• Created $COMPILED_PATH\n", bold=true)
else
    try
        rm(COMPILED_PATH, recursive=true, force=true)
        mkdir(COMPILED_PATH)
        printstyled("• Cleaned up $COMPILED_PATH\n", bold=true)
    catch
        printstyled("! Could not clean up $COMPILED_PATH, will try to continue...\n", color=:yellow)
    end
end


####################
### Dependencies ###
####################

using Pkg
try
    # Add project depedencies to the required ones
    Pkg.activate(PROJECT_DIR)
    Pkg.instantiate()
    #for pkg in keys(Pkg.installed())
    #    push!(REQUIRED_PACKAGES, pkg)
    #end
catch e
    printstyled("! Could not read $PROJECT_NAME package dependencies!\n($e)", color=:yellow)
end

printstyled("• Dependencies are: $REQUIRED_PACKAGES\n", bold=true)
Pkg.activate(BASE_ENV_PATH)  # reactivate default environment
Pkg.update()
for pkg in REQUIRED_PACKAGES
    if  !(pkg in (p.name for p in values(Pkg.dependencies())))
        if pkg in keys(PACKAGE_REVS)
            # Add custom revision, branch etc
            url, rev = PACKAGE_REVS[pkg]
            Pkg.add(PackageSpec(url=url, rev=rev))
        else
            # Add registered version
            Pkg.add(pkg)
        end
    end
end
printstyled("• Installed dependencies\n", bold=true)

# Re-add DataLinter to datalinter dependencies (i.e. re-build Manifest.toml)
# to make sure it is up to date
for (target, target_path) in zip(TARGETS, TARGETS_PATHS)
    cd(target_path)
    isfile("Manifest.toml") && rm("Manifest.toml", force=true)
    printstyled("• Adding latest $PROJECT_NAME to $(uppercase(target))...\n", bold=true)
    Pkg.activate(target_path)
    Pkg.add(path=PROJECT_DIR)
    Pkg.update()
    Pkg.precompile()
end

########################
### Build Executable ###
########################

if length(ARGS) != 0 && ARGS[1] == "--deps-only"
    printstyled("• Skipping build (--deps-only)\n", bold=true)
else
    # Check that all targets exist
    for target in TARGETS_PATHS
        if !isdir(target)
            printstyled("× Could not find $target. Exiting...\n", color=:red, bold=true)
            exit()
        end
    end

    using PackageCompiler
    cd(APPS_PATH)
    Pkg.activate(PROJECT_DIR)
    for (i, target) in enumerate(TARGETS)
        printstyled("• Building: $(uppercase(target)) ...\n", color=:green, bold=true)
        create_app(target,
                   joinpath(COMPILED_PATH, target);
                   precompile_execution_file=PRECOMPILE_FILES,
                   force=true,
                   cpu_target=CPU_TARGET)
    end
    printstyled("• Build complete.\n", bold=true)
end

#Packaging
#const ARCHIVE_NAME="tardisk"
#cd(COMPILED_PATH)
#for target in TARGETS
#    ARCHIVES_PATH = joinpath(COMPILED_PATH, "$(target)_archived")
#    isdir(ARCHIVES_PATH) && rm(ARCHIVES_PATH, recursive=true, force=true)
#    try
#        mkdir(ARCHIVES_PATH)
#        run(pipeline(`tar czpvf - $target`, `split -d -b 100M - $ARCHIVE_NAME`))
#        for entry in readdir(".")
#            startswith(entry, ARCHIVE_NAME) && isfile(entry) && run(`mv ./$entry $ARCHIVES_PATH`)
#        end
#        @info "Archiving complete for $(uppercase(target)) @$(ARCHIVES_PATH)"
#    catch e
#        @warn "Something went wrong in archiving app $(uppercase(target))"
#        isdir(ARCHIVES_PATH) && rm(ARCHIVES_PATH, recursive=true, force=true)
#        run(`rm ./$ARCHIVE_NAME'*'`)
#        @info "Cleanup complete."
#    end
#end
