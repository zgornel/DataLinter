@testset "Data" begin

    using Tables
    import DataLinter.DataInterface as DI

    @testset "CodeAndDataContext" begin
        @test DI.CodeAndDataContext <: DataLinter.LinterCore.AbstractContext
        @test DI.CodeAndDataContext(1, nothing) isa DI.CodeAndDataContext
        @test DI.CodeAndDataContext(data = 1) == DI.CodeAndDataContext(1, nothing)
    end

    @testset "DataContext" begin
        @test DI.DataContext <: DataLinter.LinterCore.AbstractContext
        @test DI.DataContext(1) isa DI.DataContext
        @test DI.DataContext(data = 1) == DI.DataContext(1)
        @test DI.DataContext() == DI.DataContext(data = nothing)
    end

    @testset "CodeContext" begin
        @test DI.CodeContext <: DataLinter.LinterCore.AbstractContext
        @test DI.CodeContext("code") isa DI.CodeContext
        @test DI.CodeContext(code = "code") == DI.CodeContext("code")
        @test DI.CodeContext() == DI.CodeContext(code = nothing)
    end

    @testset "build_data_context" begin
        data = Tables.Columns((a = [1, 2, 3], b = [3, 2, 1]))
        code = nothing  # todo: change to value representative of real use
        code2 = "code"

        @testset "CodeAndDataContext" begin
            context = DI.build_data_context(data, code)
            @test context isa DI.CodeAndDataContext
            @test context.data == data
            @test context.code == code
            @test DI.get_context_code(context) == code
            @test DI.get_context_data(context) == data
        end

        @testset "DataContext" begin
            context = DI.build_data_context(data)
            @test context isa DI.DataContext
            @test context.data == data
            @test DI.get_context_code(context) == nothing
            @test DI.get_context_data(context) == data
        end

        @testset "CodeContext" begin
            context = DI.build_data_context(nothing, code2)
            @test context isa DI.CodeContext
            @test context.code == code2
            @test DI.get_context_code(context) == code2
            @test DI.get_context_data(context) == nothing
        end

    end

end

@testset "build_data_iterator" begin
    tbl = Tables.Columns((a = [1, 2, 3], b = [3, 2, 1]))
    dict_tbl = Dict(:a => [1, 2, 3], :b => [3, 2, 1])
    @test DI.build_data_iterator(tbl) isa DataLinter.LinterCore.DataIterator
    @test DI.build_data_iterator(dict_tbl) isa DataLinter.LinterCore.DataIterator

    nothing_it = DI.build_data_iterator(nothing)
    @test nothing_it isa DataLinter.LinterCore.DataIterator
    @test nothing_it.column_iterator == []
    @test nothing_it.row_iterator == []
    @test nothing_it.tblref isa Ref{Nothing}
end
