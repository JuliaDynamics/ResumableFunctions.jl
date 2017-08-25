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
  repo = "github.com/benlauwens/ResumableFunctions.jl.git"
)