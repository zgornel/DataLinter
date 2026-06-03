@testset "KB native linters (.csv + R)" begin
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

    @testset "process_formula_variables" begin
        import DataLinter.KnowledgeBaseNative: process_formula_variables
        data = Tables.table([1;2;3;;10;20;30;;30;40;50;;60;70;80]; header = [:y, :x1, :x2, :x3])

        formula = "y~."; target_variable, rhs = String.(split(formula, "~"))
        @test process_formula_variables(target_variable, rhs, data) == (:y, setdiff(Tables.columnnames(data), [:y]))
        @test process_formula_variables(Tables.columnindex(data, Symbol(target_variable)), rhs, data) == (:y, setdiff(Tables.columnnames(data), [:y]))

        formula = "x1~x2+x3"; target_variable, rhs = String.(split(formula, "~"))
        @test process_formula_variables(target_variable, rhs, data) == (:x1, [:x2, :x3])
        @test process_formula_variables(Tables.columnindex(data, Symbol(target_variable)), rhs, data) == (:x1, [:x2, :x3])
    end
end
