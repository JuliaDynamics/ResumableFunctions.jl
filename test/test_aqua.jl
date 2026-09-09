using Aqua
using ResumableFunctions

Aqua.test_all(ResumableFunctions; deps_compat = (; check_weakdeps = false))
