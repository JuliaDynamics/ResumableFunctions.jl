using Documenter
using ResumableFunctions

@testset "Doctests" begin
    DocMeta.setdocmeta!(ResumableFunctions, :DocTestSetup, :(using ResumableFunctions); recursive=true)
    doctest(ResumableFunctions)
end
