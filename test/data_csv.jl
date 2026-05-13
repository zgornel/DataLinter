@testset "Data: CSV plugin" begin
    using Tables

    @testset "build_data_context" begin
        code = "x=1; foo = x=> x+ 1; foo(x) |> print"

        @testset "SimpleDataContext (from CSV)" begin
            context = DI.build_data_context("data/data.csv")
            @test context isa DI.SimpleDataContext
            @test DI.build_data_iterator(context) isa DataLinter.LinterCore.DataIterator{<:Tables.Columns}
        end

        @testset "SimpleDataContext (from CSV)" begin
            context = DI.build_data_context("data/data.csv", code)
            @test context isa DI.SimpleCodeAndDataContext
            @test DI.build_data_iterator(context) isa DataLinter.LinterCore.DataIterator{<:Tables.Columns}
        end
    end
end
