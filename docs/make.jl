using Documenter
using ResumableFunctions

makedocs(
  sitename = "ResumableFunctions",
  authors = "Ben Lauwens and volunteers from JuliaDynamics and QuantumSavory",
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
