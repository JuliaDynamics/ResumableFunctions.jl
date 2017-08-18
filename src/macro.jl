using MacroTools: postwalk, striplines, flatten, unresolve, resyntax

macro resumable(expr::Expr)
  expr.head != :function && error("Expression is not a function definition!")
  func_def = splitdef(expr)

  new_expr = postwalk(transform_for, expr)
  new_expr = new_expr |> striplines |> flatten |> unresolve |> resyntax
  println(new_expr)
  println(func_def[:body])
  func_def[:body] = new_expr
  println(func_def[:body])
  slots = getslots(copy(func_def))
  println(slots)
  type_name = gensym()
  esc(new_expr)
end
