using ResumableFunctions
using JET
using Test

using JET: ReportPass, BasicPass, InferenceErrorReport, UncaughtExceptionReport

# Custom report pass that ignores `UncaughtExceptionReport`
# Too coarse currently, but it serves to ignore the various
# "may throw" messages for runtime errors we raise on purpose
# (mostly on malformed user input)
struct MayThrowIsOk <: ReportPass end

# ignores `UncaughtExceptionReport` analyzed by `JETAnalyzer`
(::MayThrowIsOk)(::Type{UncaughtExceptionReport}, @nospecialize(_...)) = return

# forward to `BasicPass` for everything else
function (::MayThrowIsOk)(report_type::Type{<:InferenceErrorReport}, @nospecialize(args...))
    BasicPass()(report_type, args...)
end

@testset "JET checks" begin
    rep = report_package("ResumableFunctions";
        report_pass=MayThrowIsOk(),
        ignored_modules=(
            Core.Compiler,
        )
    )
    @show rep
    @test length(JET.get_reports(rep)) <= 8
    @test_broken length(JET.get_reports(rep)) == 0
end
