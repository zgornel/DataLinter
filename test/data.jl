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
        data_dict = Dict("vector" => [1, 2, 3], "matrix" => rand(2, 2))
        code = nothing  # todo: change to value representative of real use
        code2 = "code"

        @testset "CodeAndDataContext (table)" begin
            context = DI.build_data_context(data, code)
            @test context isa DI.CodeAndDataContext
            @test context.data == data
            @test context.code == code
            @test DI.get_context_code(context) == code
            @test DI.get_context_data(context) == data
        end

        @testset "CodeAndDataContext (dict)" begin
            context = DI.build_data_context(data_dict, code)
            @test context isa DI.CodeAndDataContext
            @test context.data == data_dict
            @test context.code == code
            @test DI.get_context_code(context) == code
            @test DI.get_context_data(context) == data_dict
        end

        @testset "CodeAndDataContext" begin
            context = DI.build_data_context(data, code)
            @test context isa DI.CodeAndDataContext
            @test context.data == data
            @test context.code == code
            @test DI.get_context_code(context) == code
            @test DI.get_context_data(context) == data
        end

        @testset "DataContext (table)" begin
            context = DI.build_data_context(data)
            @test context isa DI.DataContext
            @test context.data == data
            @test DI.get_context_code(context) == nothing
            @test DI.get_context_data(context) == data
        end

        @testset "DataContext (dict)" begin
            context = DI.build_data_context(data_dict)
            @test context isa DI.DataContext
            @test context.data == data_dict
            @test DI.get_context_code(context) == nothing
            @test DI.get_context_data(context) == data_dict
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
    @testset "build_data_iterator (table)" begin
        tbl = Tables.Columns((a = [1, 2, 3], b = [3, 2, 1]))
        tbl_it = DI.build_data_iterator(tbl)
        @test tbl_it isa DataLinter.LinterCore.DataIterator
        @test typeof(tbl_it.column_iterator) <: Tables.Columns
        @test typeof(tbl_it.row_iterator) <: Tables.RowIterator
        @test typeof(tbl_it.dataref) <: Ref{<:Tables.Columns}

        dict_tbl = Dict(:a => [1, 2, 3], :b => [3, 2, 1])
        dict_tbl_it = DI.build_data_iterator(dict_tbl)
        @test dict_tbl_it isa DataLinter.LinterCore.DataIterator
        @test typeof(dict_tbl_it.column_iterator) <: Tables.Columns
        @test typeof(dict_tbl_it.row_iterator) <: Tables.RowIterator
        @test typeof(dict_tbl_it.dataref) <: Ref{<:Tables.Columns}

    end

    @testset "build_data_iterator (table)" begin
        dict = Dict("a" => [1, 2, 3], "b" => [3, 2, 1])
        dict_it = DI.build_data_iterator(dict)
        @test dict_it isa DataLinter.LinterCore.DataIterator
        @test dict_it.column_iterator == []
        @test dict_it.row_iterator == []
        @test typeof(dict_it.dataref) <: Ref{<:AbstractDict{<:String}}
    end

    @testset "build_data_iterator (nothing)" begin
        nothing_it = DI.build_data_iterator(nothing)
        @test nothing_it isa DataLinter.LinterCore.DataIterator
        @test nothing_it.column_iterator == []
        @test nothing_it.row_iterator == []
        @test nothing_it.dataref isa Ref{Nothing}
    end

end
