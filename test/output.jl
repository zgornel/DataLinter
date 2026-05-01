@testset "OutputInterface" begin
    import DataLinter.LinterCore: Linter
    import DataLinter.OutputInterface as OI
    TEST_PATH = abspath(dirname(@__FILE__))
    kb = nothing
    filepath = joinpath(TEST_PATH, "data", "imbalanced_data.csv")
    codepath = joinpath(TEST_PATH, "code", "r_snippet_imbalanced.r")
    config_path = joinpath(TEST_PATH, "test_config.toml")
    config = DataLinter.LinterCore.load_config(config_path)
    ctx = DataLinter.DataInterface.build_data_context(filepath, read(codepath, String))
    out = DataLinter.lint(ctx, kb; config = config)
    @test OI.score(out; normalize = true) isa Number
    @test OI.score(out; normalize = false) isa Number
    buf = IOBuffer()
    @test OI.process_output(
        out;
        buffer = buf,
        show_stats = false,
        show_passing = false,
        show_na = false
    ) == nothing  # just run it
end
