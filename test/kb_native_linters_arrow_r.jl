@testset "KB native linters (.arrow + R)" begin
    @testset "test_config.toml linters" begin
        import DataLinter.LinterCore: Linter
        TEST_PATH = abspath(dirname(@__FILE__))
        kb = nothing

        DATA_PATHS = [
            # .arrow
            joinpath(TEST_PATH, "data", "correlated_data.arrow"),
            joinpath(TEST_PATH, "data", "correlated_target_data.arrow"),
            joinpath(TEST_PATH, "data", "imbalanced_data.arrow"),
            joinpath(TEST_PATH, "data", "data.arrow"),
        ]
        CODE_PATHS = [
            joinpath(TEST_PATH, "code", "r_snippet_binomial.r"),
            joinpath(TEST_PATH, "code", "r_snippet_imbalanced.r"),
            joinpath(TEST_PATH, "code", "r_snippet_lm.r"),
        ]

        for filepath in DATA_PATHS
            for codepath in CODE_PATHS
                config_path = joinpath(TEST_PATH, "test_config.toml")
                config = DataLinter.LinterCore.load_config(config_path)
                ctx = DataLinter.DataInterface.build_data_context(filepath, read(codepath, String))
                out = DataLinter.lint(ctx, kb; config = config)
                # Basic functionality test: output works and type assertion
                @test !isempty(out)
                @test out isa Vector{Pair{Tuple{Linter, String}, DataLinter.LinterCore.AbstractCheck}}
            end
        end
    end

end
