@testset "KnowledgeBase" begin

    using TOML
    import DataLinter.KnowledgeBaseInterface as KB

    @testset "KnowledgeBaseWrapper" begin
        @test KB.KnowledgeBaseWrapper <: DataLinter.LinterCore.AbstractKnowledgeBase
    end

    @testset "kb_load" begin
        @testset "non-existent path" begin
            kb = KB.kb_load("")
            @test kb isa KB.KnowledgeBaseWrapper
            @test kb.data isa KB.KnowledgeBaseNative.KnowledgeBase
            @test isempty(kb.data.data)
        end

        @testset "existing path" begin
            data = Dict("a"=>1)
            mktemp() do kbpath, io
                TOML.print(io, data)
                flush(io);
                kb = kb_load(kbpath);
                @test kb isa KB.KnowledgeBaseWrapper
                @test kb.data isa KB.KnowledgeBaseNative.KnowledgeBase
                @test kb.data.data == data
            end
        end
    end
end
