using ExplicitImports
using ResumableFunctions
using Test

@testset "ExplicitImports tests" begin
    @test check_no_implicit_imports(ResumableFunctions) === nothing
    @test_broken check_no_stale_explicit_imports(ResumableFunctions) === nothing
    @test check_all_explicit_imports_via_owners(ResumableFunctions) === nothing

    # MacroTools.jl has been inconsistent in marking documented functions as public (or exporting them), 
    # gradually doing different ones over different versions. So work around that.
    nonpublic_ignore = ()
    macrotools_module = @eval(ResumableFunctions,
        only(filter((k, v)::Pair -> k.name == "MacroTools", Base.loaded_modules)).second)
    if pkgversion(macrotools_module) < v"0.5.10"
        nonpublic_ignore = (:flatten, :postwalk, :striplines, :combinedef, :combinearg)
    elseif pkgversion(macrotools_module) < v"0.5.17"
        nonpublic_ignore = (:flatten, :postwalk, :striplines)
    end
    #@test check_all_explicit_imports_are_public(ResumableFunctions; ignore=nonpublic_ignore) === []

    @test check_all_qualified_accesses_via_owners(ResumableFunctions;
        skip=(Base => Core, Core.Compiler => Base)) === nothing
end

