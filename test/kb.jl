@testset "KnowledgeBase" begin

    using TOML
    import DataLinter.KnowledgeBaseInterface as KB
    import DataLinter.KnowledgeBaseNative as KBN

    @testset "KnowledgeBase" begin
        @test KBN.KnowledgeBase <: DataLinter.LinterCore.AbstractKnowledgeBase
    end

    @testset "kb_load" begin
        @testset "non-existent path" begin
            kb = KB.kb_load("")
            @test typeof(kb) <: KB.AbstractKnowledgeBase
            @test kb isa DataLinter.KnowledgeBaseNative.KnowledgeBase
            @test kb.data isa Dict
            @test isempty(kb.data)
        end

        @testset "existing path" begin
            data = Dict("a"=>1)
            mktemp() do kbpath, io
                TOML.print(io, data)
                flush(io);
                kb = kb_load(kbpath);
                @test typeof(kb) <: KB.AbstractKnowledgeBase
                @test kb isa DataLinter.KnowledgeBaseNative.KnowledgeBase
                @test kb.data isa Dict
                @test kb.data == data
            end
        end
    end
end
