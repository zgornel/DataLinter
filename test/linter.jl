@testset "Linter" begin

	import DataLinter.LinterCore as LC

	@testset "LinterStruct" begin
		@test fieldnames(LC.Linter) == (:name, :description, :f, :failure_message, :correct_message, :warn_level, :correct_if)
		@test fieldtypes(LC.Linter) == (Symbol, String, Function, Function, Function, String, Function)
	end

end
