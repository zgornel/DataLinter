using TOML

const SAMPLE_CONFIG = """
[linters]
    sample_linter = true
    another_linter = false
[parameters]
    [parameters.sample_linter]
        x=2
        y="a"
        z=[1,2,3]
    [parameters.another_linter]
        #has_no_kwargs
"""

@testset "Configuration" begin

    import DataLinter.Configuration as Cfg
    # load_config
    @test Cfg.FALLBACK_CONFIG === nothing
    @test Cfg.load_config(nothing) == Cfg.FALLBACK_CONFIG
    @test Cfg.load_config(IOBuffer(SAMPLE_CONFIG)) == TOML.parse(IOBuffer(SAMPLE_CONFIG))
    mktemp(tempdir()) do configpath, io
        write(io, SAMPLE_CONFIG)
        flush(io)
        @test Cfg.load_config(configpath) == Cfg.load_config(IOBuffer(SAMPLE_CONFIG))
    end
    @test Cfg.load_config("") === Cfg.FALLBACK_CONFIG

    # linter_is_enabled
    foo(; x = 1, y = "b") = (x, y)
    linter = DataLinter.LinterCore.Linter(
        name = :sample_linter,
        description = """ A sample linterr""",
        f = foo,
        failure_message = name -> "",
        correct_message = name -> "",
        warn_level = "info",
        correct_if = x -> x == true,
        query = nothing,
        programming_language = nothing,
        requirements = Dict{String, Any}()
    )
    @test Cfg.linter_is_enabled(nothing, linter)
    @test Cfg.linter_is_enabled(Cfg.load_config(IOBuffer(SAMPLE_CONFIG)), linter) == true # linter is NOT in config

    for val in [true, false, 0, 1]
        @test Cfg.linter_is_enabled(Dict("linters" => Dict("sample_linter" => val)), linter) == Bool(val)
    end

    # get_linter_kwargs
    @test Cfg.get_linter_kwargs(nothing, linter) == ()
    @test Cfg.get_linter_kwargs(Cfg.load_config(IOBuffer(SAMPLE_CONFIG)), linter) == Pair{Symbol, Any}[:x => 2, :y => "a"]
    @test Cfg.get_linter_kwargs(Dict(), linter) == []

    # get_experiment_parameters
    @test Cfg.get_experiment_parameters(nothing) == nothing
    sample_config_ex_params = Cfg.get_experiment_parameters(TOML.parse(IOBuffer(SAMPLE_CONFIG)))
    @test sample_config_ex_params isa NamedTuple
    @test length(propertynames(sample_config_ex_params)) == 6
    EX_PROPS = (
        :name, :analysis_type, :analysis_subtype,
        :target_variable, :data_variables, :programming_language,
    )
    @test all(k in propertynames(sample_config_ex_params) for k in EX_PROPS)
    @test sample_config_ex_params.name == Cfg.DEFAULT_EXPERIMENT_NAME
    @test all(
        getproperty(sample_config_ex_params, k) === nothing
            for k in propertynames(sample_config_ex_params)
            if k != :name
    )
end
