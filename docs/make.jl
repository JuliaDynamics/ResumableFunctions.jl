using Documenter
using Semicoroutines

makedocs(
  sitename = "Semicoroutines",
  authors = "Semicoroutines contributors",
  pages = [
    "Home" => "index.md",
    "Manual" => "manual.md",
    "Internals" => "internals.md",
    "Library" => "library.md"
  ]
)

deploydocs(
  repo = "github.com/QuantumSavory/Semicoroutines.jl"
)
