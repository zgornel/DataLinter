@testset "Data: Parquet plugin" begin
    using Parquet

    @testset "build_data_context" begin
        code = "x=1; foo = x=> x+ 1; foo(x) |> print"

        @testset "DataContext (from Parquet)" begin
            context = DI.build_data_context("data/data.parquet")
            @test context isa DI.DataContext
            @test DI.build_data_iterator(context) isa DataLinter.LinterCore.DataIterator{<:Parquet.Table}
        end

        @testset "DataContext (from Parquet)" begin
            context = DI.build_data_context("data/data.parquet", code)
            @test context isa DI.CodeAndDataContext
            @test DI.build_data_iterator(context) isa DataLinter.LinterCore.DataIterator{<:Parquet.Table}
        end
    end
end
