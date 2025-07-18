@testset "Linter" begin

	import DataLinter.LinterCore as LC

	@testset "Linter struct" begin
		@test fieldnames(LC.Linter) == (:name, :description, :f, :failure_message,
                                        :correct_message, :warn_level, :correct_if,
                                        :query, :programming_language, :requirements)
		@test fieldtypes(LC.Linter) == (Symbol, String, Function, Function,
                                        Function, String, Function,
                                        Union{Nothing, Tuple}, Union{Nothing, String}, Dict{String})
	end
	@testset "LintingContext struct" begin
		@test fieldnames(LC.LintingContext) == (:name, :analysis_type, :analysis_subtype,
                                                :target_variable, :data_variables, :programming_language,
                                                :parsing_data)
		@test fieldtypes(LC.LintingContext) == (String, Union{Nothing,String},Union{Nothing,String},
                                                Union{Nothing, Int, String}, Union{Nothing, Vector{Int}, Vector{String}},
                                                Union{Nothing, String}, Any )
	end

end
