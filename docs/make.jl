using Documenter
using AnythingLLMDocs
using ResumableFunctions

doc_modules = [ResumableFunctions]

api_base="https://anythingllm.krastanov.org/api/v1"
anythingllm_assets = integrate_anythingllm(
  "ResumableFunctions",
  doc_modules,
  @__DIR__,
  api_base;
  repo = "github.com/JuliaDynamics/ResumableFunctions.jl",
  options = EmbedOptions(),
)

makedocs(
  sitename = "ResumableFunctions",
  authors = "Ben Lauwens and volunteers from JuliaDynamics and QuantumSavory",
  format = Documenter.HTML(assets = anythingllm_assets),
  modules = doc_modules,
  pages = [
    "Home" => "index.md",
    "Manual" => "manual.md",
    "Internals" => "internals.md",
    "Library" => "library.md"
  ]
)

deploydocs(
  repo = "github.com/JuliaDynamics/ResumableFunctions.jl"
)
