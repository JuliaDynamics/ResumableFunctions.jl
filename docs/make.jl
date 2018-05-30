using Documenter
using ResumableFunctions

makedocs(
  format = :html,
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
  julia = "nightly",
  repo = "github.com/BenLauwens/ResumableFunctions.jl",
  target = "build",
  deps   = nothing,
  make   = nothing
)
