using ResumableFunctions
using JET
using Test

@testset "JET checks" begin
    rep = report_package("ResumableFunctions";
        ignored_modules=(
            Core.Compiler,
        )
    )
    @show rep
    @test length(JET.get_reports(rep)) <= 8
    @test_broken length(JET.get_reports(rep)) == 0
end
