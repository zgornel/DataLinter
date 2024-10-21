module Configuration

using TOML
import ..LinterCore: load_config, linter_is_enabled, get_linter_params


const FALLBACK_CONFIG = nothing


# Function that loads the configuration for the linter
load_config(::Nothing) = FALLBACK_CONFIG
load_config(io::IO) = TOML.parse(io)
load_config(configpath::AbstractString) = begin
    config = try
            open(configpath, "r") do io
                load_config(io)
            end
        catch e
           @warn "Could not parse configuration @\"$configpath\", using default configuration.\n$e"
           FALLBACK_CONFIG
        end
    return config
end


# Function that returns whether a linter is enabled in the config or not
linter_is_enabled(::Nothing, linter) = true  # by default, if config is not present, linters are enabled
linter_is_enabled(config::Dict, linter) = begin
    value = try
            config["linters"][string(linter.name)] |> Bool
        catch e
            @warn "Could not read config>[linters]>[$(linter.name)]. Linter will be enabled by default.\n$e"
            true
        end
    return value
end


# Function that reads linter configuration parameters
get_linter_params(config::Nothing, linter) = ()  # if config is missing, broken, default parameters are kept
get_linter_params(config::Dict, linter) = begin
    cfg_params = try
                    ( Symbol(k)=>v for (k,v) in config["parameters"][linter.name] )
                catch e
                    #@warn "Could not read config>[parameters]>[$(linter.name)]. Linter will use default parameters.\n$e"
                    ()
                end
    f_kwargs = vcat(Base.kwarg_decl.(methods(linter.f))...)  # get kwargs of linter function
    return [k=>v for (k,v) in cfg_params if k in f_kwargs]   # return only kwargs that are in the list of the functions kwargs
end

end  # module
