@testset "KB native linters (.csv + Python)" begin
    @testset "test_config.toml linters" begin
        import DataLinter.LinterCore: Linter
        TEST_PATH = abspath(dirname(@__FILE__))
        kb = nothing

        DATA_PATHS = [
            # .csv
            joinpath(TEST_PATH, "data", "correlated_data.csv"),
            joinpath(TEST_PATH, "data", "correlated_target_data.csv"),
            joinpath(TEST_PATH, "data", "imbalanced_data.csv"),
            joinpath(TEST_PATH, "data", "data.csv"),
        ]
        CODE_PATHS = [
            joinpath(TEST_PATH, "code", "python_snippet_imbalanced.py"),
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

    @testset "Python_imbalanced_target_variable" begin
        import DataLinter.LinterCore: Linter, FailedCheck, PassedCheck
        TEST_PATH = abspath(dirname(@__FILE__))
        kb = nothing
        config_path = joinpath(TEST_PATH, "test_config.toml")
        config = DataLinter.LinterCore.load_config(config_path)
        codepath = joinpath(TEST_PATH, "code", "python_snippet_imbalanced.py")
        datapath = joinpath(TEST_PATH, "data", "imbalanced_data.csv")

        ctx = DataLinter.DataInterface.build_data_context(datapath, read(codepath, String))
        out = DataLinter.lint(ctx, kb; config = config, linters = ["python"])
        @test length(out) == 1
        (linter, _), result = only(out)
        @test linter.name == :Python_imbalanced_target_variable
        @test result isa FailedCheck  # col4 is heavily imbalanced (99 x 1.0, 1 x 0.0)

        # A balanced/continuous target should not trigger the linter
        balanced_code = replace(read(codepath, String), "col4" => "col1")
        ctx_balanced = DataLinter.DataInterface.build_data_context(datapath, balanced_code)
        out_balanced = DataLinter.lint(ctx_balanced, kb; config = config, linters = ["python"])
        @test length(out_balanced) == 1
        (_, _), result_balanced = only(out_balanced)
        @test result_balanced isa PassedCheck
    end
end
