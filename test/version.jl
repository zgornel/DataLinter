@testset "version" begin
    v = DataLinter.version()
    @test length(v) == 3
    @test v isa Tuple{String, String, String}

    pv = DataLinter.printable_version()
    @test pv isa String
    @test contains(pv, "DataLinter")
end
