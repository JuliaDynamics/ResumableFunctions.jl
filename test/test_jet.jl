using ResumableFunctions
using JET
using Test

@testset "JET checks" begin
    rep = report_package("ResumableFunctions";
        ignored_modules=(
            Core.Compiler,
        )
    )
    @test length(JET.get_reports(rep)) <= 7
    @test_broken length(JET.get_reports(rep)) == 0
end
