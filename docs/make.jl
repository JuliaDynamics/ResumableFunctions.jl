using Documenter
using ResumableFunctions

makedocs(
  format = :html,
  sitename = "ResumableFunctions",
  pages = [
      "index.md",
  ]
)

deploydocs(
  repo = "github.com/BenLauwens/ResumableFunctions.jl",
  target = "build",
  deps   = nothing,
  make   = nothing
)