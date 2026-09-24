@testset "Data: Dict plugin" begin
    using Tables

    @testset "build_data_context" begin
        code = "x=1; foo = x=> x+ 1; foo(x) |> print"

        @testset "DataContext (from generic (JSON) Dict)" begin
            context = DI.build_data_context("{\"a\":\"[1,2,3]\"}")
            @test context isa DI.DataContext
            @test DI.build_data_iterator(context) isa DataLinter.LinterCore.DataIterator{<:Dict{<:AbstractString}}
        end

        @testset "DataContext (from generic (JSON) Dict)" begin
            context = DI.build_data_context("{\"a\":\"[1,2,3]\"}", code)
            @test context isa DI.CodeAndDataContext
            @test DI.build_data_iterator(context) isa DataLinter.LinterCore.DataIterator{<:Dict{<:AbstractString}}
        end
    end
end
