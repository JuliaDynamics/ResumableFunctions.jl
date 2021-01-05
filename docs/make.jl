using Documenter
using ResumableFunctions

makedocs(
  sitename = "ResumableFunctions",
  authors = "Ben Lauwens",
  pages = [
    "Home" => "index.md",
    "Manual" => "manual.md",
    "Internals" => "internals.md",
    "Library" => "library.md"
  ]
)

deploydocs(
  repo = "github.com/BenLauwens/ResumableFunctions.jl"
)
