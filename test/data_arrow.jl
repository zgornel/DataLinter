@testset "Data: Arrow plugin" begin
    using Arrow

    @testset "build_data_context" begin
        code = "x=1; foo = x=> x+ 1; foo(x) |> print"

        @testset "SimpleDataContext (from Arrow)" begin
            context = DI.build_data_context("data/data.arrow")
            @test context isa DI.SimpleDataContext
            @test DI.build_data_iterator(context) isa DataLinter.LinterCore.DataIterator{<:Arrow.Table}
        end

        @testset "SimpleDataContext (from Arrow)" begin
            context = DI.build_data_context("data/data.arrow", code)
            @test context isa DI.SimpleCodeAndDataContext
            @test DI.build_data_iterator(context) isa DataLinter.LinterCore.DataIterator{<:Arrow.Table}
        end
    end
end
