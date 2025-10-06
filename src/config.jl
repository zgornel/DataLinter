module Configuration

using TOML
import ..LinterCore: load_config, linter_is_enabled, get_linter_kwargs,
    get_experiment_parameters
const FALLBACK_CONFIG = nothing

"""
    load_config(configpath::AbstractString)

Loads a linting configuration file located at `configpath`.
The configuration file contains options regarding which linters
are enabled and linter parameter values.

# Examples
```julia
julia> using DataLinter
       using Pkg
        configpath = joinpath(dirname((Pkg.project()).path), "config", "default.toml")
       DataLinter.LinterCore.load_config(configpath)
Dict{String, Any} with 2 entries:
  "parameters" => Dict{String, Any}("uncommon_signs"=>Dict{String, Any}(), "enum_detector"=>Dict{String, Any}("distinct_max_limit"=>5, "distinct_ratio"=>0.001), "empty_example"=>Dict{String, Any}(), "negative_…
  "linters"    => Dict{String, Any}("uncommon_signs"=>true, "enum_detector"=>true, "empty_example"=>true, "negative_values"=>true, "tokenizable_string"=>true, "number_as_string"=>true, "int_as_float"=>true, "l…
```
"""
load_config(::Nothing) = FALLBACK_CONFIG
load_config(io::IO) = TOML.parse(io)
load_config(configpath::AbstractString) = begin
    config = try
        open(configpath, "r") do io
            load_config(io)
        end
    catch e
        @warn "Could not parse configuration @\"$configpath\", using default configuration.\n"
        FALLBACK_CONFIG
    end
    return config
end

"""
Function that returns whether a linter is enabled in the config or not.
"""
linter_is_enabled(::Nothing, linter) = false  # by default, if config is not present, linters are disabled
linter_is_enabled(config::Dict, linter) = begin
    value = try
        config["linters"][string(linter.name)] |> Bool
    catch e
        @debug "Linter from KB, not found in config: [linters]->[$(linter.name)]. Linter will be disabled by default.\n$e"
        false
    end
    return value
end

"""
Function that reads linter configuration parameters.
"""
get_linter_kwargs(config::Nothing, linter) = ()  # if config is missing, broken, default parameters are kept
get_linter_kwargs(config::Dict, linter) = begin
    SKIP_KWARGS = [Symbol("kwargs...")]  # kwargs no to consider when matching config parameters and function kwargs
    cfg_params = try
        (Symbol(k) => v for (k, v) in config["parameters"][string(linter.name)])
    catch e
        @debug "Could not read linter parameters in config: [parameters]->[$(linter.name)]. Linter will use default parameters.\n$e"
        ()
    end
    f_kwargs = unique(v for v in vcat(Base.kwarg_decl.(methods(linter.f))...) if !in(v, SKIP_KWARGS)) # get kwargs of linter function
    linter_kwargs = [k => v for (k, v) in cfg_params if k in f_kwargs]   # return only kwargs that are in the list of the functions kwargs
    # config params for a linter that are in config but cannot be set as kwargs of the linters' function
    cfg_params_toomany = setdiff((k for (k, v) in cfg_params), f_kwargs)
    if !isempty(cfg_params_toomany)
        @debug "$(linter.name): [$(cfg_params_toomany...)] parameters from config could not be set"
    end
    return linter_kwargs
end


const DEFAULT_EXPERIMENT_NAME = "Default experiment name"
"""
Function that reads linter configuration parameters.
"""
get_experiment_parameters(config::Nothing) = nothing  # if config is missing, broken, default parameters are kept
get_experiment_parameters(config::Dict) = begin
    _ctx = get(config, "experiment", Dict())
    return (
        name = get(_ctx, "name", DEFAULT_EXPERIMENT_NAME),
        analysis_type = get(_ctx, "analysis_type", nothing),
        analysis_subtype = get(_ctx, "analysis_subtype", nothing),
        target_variable = get(_ctx, "target_variable", nothing),
        data_variables = _parse_vector_values(get(_ctx, "data_variables", nothing)),
        programming_language = get(_ctx, "programming_language", nothing),
    )
end

# Some custom parsing of values for config fields
_parse_vector_values(::Nothing) = nothing

_parse_vector_values(_v::Vector{String}) = begin
    try
        [parse(Int, _vi) for _vi in _v]
    catch
        _v
    end
end

_parse_vector_values(_v::AbstractVector) = begin
    isempty(_v) && return Vector{Int}()
    @error "Could not parse vector of values from configuration"
end

end  # module
