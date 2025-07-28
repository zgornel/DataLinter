@testset "Linter" begin
    #TODO: build tests for `build_linting_context`, `lint`

    import DataLinter.LinterCore as LC

    @testset "Linter struct" begin
        @test fieldnames(LC.Linter) == (
            :name, :description, :f, :failure_message,
            :correct_message, :warn_level, :correct_if,
            :query, :programming_language, :requirements,
        )
        @test fieldtypes(LC.Linter) == (
            Symbol, String, Function, Function,
            Function, String, Function,
            Union{Nothing, Tuple}, Union{Nothing, String}, Dict{String},
        )
    end
    @testset "LintingContext struct" begin
        @test fieldnames(LC.LintingContext) == (
            :name, :analysis_type, :analysis_subtype,
            :target_variable, :data_variables, :programming_language,
            :parsing_data,
        )
        @test fieldtypes(LC.LintingContext) == (
            String, Union{Nothing, String}, Union{Nothing, String},
            Union{Nothing, Int, String}, Union{Nothing, Vector{Int}, Vector{String}},
            Union{Nothing, String}, Any,
        )
    end
    @testset "reconcile_contexts" begin
        config_ctx = LC.LintingContext("Ctx1", "analysis1", nothing, 2, nothing, nothing, nothing)
        code_ctx = LC.LintingContext("Ctx2", "analysis2", "classification", nothing, nothing, "c", (key1 = "val1",))
        r_ctx = LC.reconcile_contexts(code_ctx, config_ctx)
        @test r_ctx.name == "Ctx2"
        @test r_ctx.analysis_type == "analysis2"
        @test r_ctx.analysis_subtype == "classification"
        @test r_ctx.target_variable == 2
        @test r_ctx.data_variables === nothing  # nothing in both
        @test r_ctx.programming_language == "c"
        @test r_ctx.parsing_data == (key1 = "val1",)

        # Other methods
        @test LC.reconcile_contexts(code_ctx, nothing) == code_ctx
        @test LC.reconcile_contexts(nothing, config_ctx) == config_ctx
        @test LC.reconcile_contexts(nothing, nothing) == nothing
    end
end
