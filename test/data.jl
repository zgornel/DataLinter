@testset "Data" begin

	using Tables
	import DataLinter.DataInterface as DI

	@testset "SimpleDataContext" begin
		@test DI.SimpleDataContext <: DataLinter.LinterCore.AbstractDataContext
		@test DI.SimpleDataContext(1) isa DI.SimpleDataContext
		@test DI.SimpleDataContext(data=1) == DI.SimpleDataContext(1)
		@test DI.SimpleDataContext() == DI.SimpleDataContext(data=nothing)
	end

	@testset "SimpleCodeAndDataContext" begin
		@test DI.SimpleCodeAndDataContext <: DataLinter.LinterCore.AbstractDataContext
		@test DI.SimpleCodeAndDataContext(1, nothing) isa DI.SimpleCodeAndDataContext
		@test DI.SimpleCodeAndDataContext(data=1) == DI.SimpleCodeAndDataContext(1, nothing)
	end

	@testset "build_data_context" begin
		data = Tables.Columns((a=[1, 2, 3], b=[3, 2, 1]))
		code = nothing  # todo: change to value representative of real use

		@testset "SimpleDataContext" begin
			context = DI.build_data_context(data)
			@test context isa DI.SimpleDataContext
			@test context.data == data
		end

		@testset "SimpleCodeAndDataContext" begin
			context = DI.build_data_context(data, code)
			@test context isa DI.SimpleCodeAndDataContext
			@test context.data == data
			@test context.code == code
		end

		@testset "SimpleDataContext (from CSV)" begin
			context = DI.build_data_context("data/data.csv")
			@test context isa DI.SimpleDataContext
		end
	end

	@testset "build_data_iterator" begin
		tbl = Tables.Columns((a=[1, 2, 3], b=[3, 2, 1]))
        dict_tbl = Dict(:a=>[1,2,3], :b=>[3,2,1])
        @test DI.build_data_iterator(tbl) isa DataLinter.LinterCore.DataIterator
        @test DI.build_data_iterator(dict_tbl) isa DataLinter.LinterCore.DataIterator
    end
end
