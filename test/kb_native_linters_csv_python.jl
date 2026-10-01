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
                ctx = DataLinter.DataInterface.build_data_context(filepath, read(codepath, String); header=true)
                out = DataLinter.lint(ctx, kb; config = config)
                # Basic functionality test: output works and type assertion
                @test !isempty(out)
                @test out isa Vector{Pair{Tuple{Linter, String}, DataLinter.LinterCore.AbstractCheck}}
            end
        end
    end

    @testset "JSON-like data" begin
        import DataLinter.LinterCore: Linter, FailedCheck, PassedCheck
        TEST_PATH = abspath(dirname(@__FILE__))
        kb = nothing
        config_path = joinpath(TEST_PATH, "test_config.toml")
        config = DataLinter.LinterCore.load_config(config_path)
        codepath = joinpath(TEST_PATH, "code", "python_snippet_multiple_inputs.py")
        datapath = joinpath(TEST_PATH, "data", "iris.json")
        ctx = DataLinter.DataInterface.build_data_context(read(datapath, String), read(codepath, String); header = false)
        out = DataLinter.lint(ctx, kb; config = config, linters = ["python"])
        @test length(out) == 1
        (linter, _), result = only(out)
        @test linter.name == :Python_imbalanced_target_variable
        @test result isa PassedCheck  # many unique values, no imbalance
    end
end
