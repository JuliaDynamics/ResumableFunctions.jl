using MacroTools: postwalk, striplines, flatten, unresolve, resyntax

macro resumable(expr::Expr)
  expr.head != :function && error("Expression is not a function definition!")
  func = splitdef(expr)
  println(func[:name])
  new_expr = postwalk(transform_for, expr)
  new_expr = new_expr |> striplines |> flatten |> unresolve |> resyntax
  println(new_expr)
  esc(new_expr)
end