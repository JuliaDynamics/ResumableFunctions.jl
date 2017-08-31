var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#ResumableFunctions-1",
    "page": "Home",
    "title": "ResumableFunctions",
    "category": "section",
    "text": "C# sharp style generators a.k.a. semi-coroutines for Julia.C# has a convenient way to create iterators [@C#Iterators] using the yield return statement. The package ResumableFunctions provides the same functionality for the Julia language by introducing the @resumable and the @yield macros. These macros can be used to replace the Task switching functions produce and consume which were deprecated in Julia v0.6. Channels are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications."
},

{
    "location": "index.html#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "ResumableFunctions is a registered package and can be installed by running:Pkg.add(\"ResumableFunctions\")"
},

{
    "location": "index.html#Example-1",
    "page": "Home",
    "title": "Example",
    "category": "section",
    "text": "using ResumableFunctions\n\n@resumable function fibonnaci(n::Int) :: Int\n  a = 0\n  b = 1\n  for i in 1:n-1\n    @yield a\n    a, b = b, a+b\n  end\n  a\nend\n\nfor fib in fibonnaci(10)\n  println(fib)\nend"
},

{
    "location": "manual.html#",
    "page": "Manual",
    "title": "Manual",
    "category": "page",
    "text": ""
},

{
    "location": "manual.html#Manual-1",
    "page": "Manual",
    "title": "Manual",
    "category": "section",
    "text": ""
},

{
    "location": "internals.html#",
    "page": "Internals",
    "title": "Internals",
    "category": "page",
    "text": ""
},

{
    "location": "internals.html#Internals-1",
    "page": "Internals",
    "title": "Internals",
    "category": "section",
    "text": ""
},

{
    "location": "library.html#",
    "page": "Library",
    "title": "Library",
    "category": "page",
    "text": ""
},

{
    "location": "library.html#Library-1",
    "page": "Library",
    "title": "Library",
    "category": "section",
    "text": ""
},

{
    "location": "library.html#ResumableFunctions",
    "page": "Library",
    "title": "ResumableFunctions",
    "category": "Module",
    "text": "Main module for ResumableFunctions.jl – C# style generators a.k.a. semi-coroutines for Julia\n\n\n\n"
},

{
    "location": "library.html#Base.done-Union{Tuple{T}, Tuple{T}, Tuple{T,UInt8}} where T<:ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "Base.done",
    "category": "Method",
    "text": "Implements the done method of the iterator interface for a subtype of FiniteStateMachineIterator.\n\n\n\n"
},

{
    "location": "library.html#Base.next-Union{Tuple{T}, Tuple{T,UInt8}} where T<:ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "Base.next",
    "category": "Method",
    "text": "Implements the next method of the iterator interface for a subtype of FiniteStateMachineIterator.\n\n\n\n"
},

{
    "location": "library.html#Base.start-Union{Tuple{T}, Tuple{T}} where T<:ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "Base.start",
    "category": "Method",
    "text": "Implements the start method of the iterator interface for a subtype of FiniteStateMachineIterator.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.@resumable-Tuple{Expr}",
    "page": "Library",
    "title": "ResumableFunctions.@resumable",
    "category": "Macro",
    "text": "Macro that transforms a function definition in a finite-statemachine:\n\nDefines a new mutable struct that implements the iterator interface and is used to store the internal state.\nMakes this new type callable having following characteristics:\nimplementents the statements from the initial function definition but;\nreturns at a @yield statement and;\ncontinues after the @yield statement when called again.\nDefines a constructor function that respects the calling conventions of the initial function definition and returns an object of the new type.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.@yield",
    "page": "Library",
    "title": "ResumableFunctions.@yield",
    "category": "Macro",
    "text": "Macro if used in a @resumable function that returns the expr otherwise returns :nothing.\n\n\n\n"
},

{
    "location": "library.html#Public-interface-1",
    "page": "Library",
    "title": "Public interface",
    "category": "section",
    "text": "Modules = [ResumableFunctions]\nPrivate = false"
},

{
    "location": "library.html#ResumableFunctions.BoxedUInt8",
    "page": "Library",
    "title": "ResumableFunctions.BoxedUInt8",
    "category": "Type",
    "text": "Mutable struct that contains a single UInt8.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "ResumableFunctions.FiniteStateMachineIterator",
    "category": "Type",
    "text": "Abstract type used as base type for the type created by the @resumable macro.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.get_slots-Tuple{Dict}",
    "page": "Library",
    "title": "ResumableFunctions.get_slots",
    "category": "Method",
    "text": "Function returning the slots of a function definition\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.make_arg_any-Tuple{Any,Dict{Symbol,Type}}",
    "page": "Library",
    "title": "ResumableFunctions.make_arg_any",
    "category": "Method",
    "text": "Function changing the type of a slot arg of a arg = @yield ret or arg = @yield statement to Any.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.remove_catch_exc-Tuple{Any,Dict{Symbol,Type}}",
    "page": "Library",
    "title": "ResumableFunctions.remove_catch_exc",
    "category": "Method",
    "text": "Function removing the exc symbol of a catch exc statement of a list of slots.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_arg-Tuple{Any}",
    "page": "Library",
    "title": "ResumableFunctions.transform_arg",
    "category": "Method",
    "text": "Function that replaces a arg = @yield ret statement  by \n\n  @yield ret; \n  arg = arg_\n\nwhere arg_ is the argument of the function containing the expression.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_exc-Tuple{Any}",
    "page": "Library",
    "title": "ResumableFunctions.transform_exc",
    "category": "Method",
    "text": "Function that replaces a @yield ret or @yield statement by \n\n  @yield ret\n  _arg isa Exception && throw(_arg)\n\nto allow that an Exception can be thrown into a @resumable function.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_for-Tuple{Any,ResumableFunctions.BoxedUInt8}",
    "page": "Library",
    "title": "ResumableFunctions.transform_for",
    "category": "Method",
    "text": "Function that replaces a for loop by a corresponding while loop saving explicitely the iterator and its state.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_slots-Tuple{Any,Base.KeyIterator{Dict{Symbol,Type}}}",
    "page": "Library",
    "title": "ResumableFunctions.transform_slots",
    "category": "Method",
    "text": "Function that replaces a variable x in an expression by _fsmi.x where x is a known slot.\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_try-Tuple{Any,ResumableFunctions.BoxedUInt8}",
    "page": "Library",
    "title": "ResumableFunctions.transform_try",
    "category": "Method",
    "text": "Function that replaces a try-catch-finally-end expression having a top level @yield statement in the try part\n\n  try\n    before_statements...\n    @yield ret\n    after_statements...\n  catch exc\n    catch_statements...\n  finally\n    finally_statements...\n  end\n\nwith a sequence of try-catch-end expressions:\n\n  try\n    before_statements...\n  catch\n    catch_statements...\n    @goto _TRY_n\n  end\n  @yield ret\n  try\n    after_statements...\n  catch\n    catch_statements...\n  end\n  @label _TRY_n\n  finally_statements...\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_yield-Tuple{Any,ResumableFunctions.BoxedUInt8}",
    "page": "Library",
    "title": "ResumableFunctions.transform_yield",
    "category": "Method",
    "text": "Function that replaces a @yield ret or @yield statement with \n\n  _fsmi._state = n\n  return ret\n  @label _STATE_n\n  _fsmi._state = 0xff\n\n\n\n"
},

{
    "location": "library.html#Internals-1",
    "page": "Library",
    "title": "Internals",
    "category": "section",
    "text": "Modules = [ResumableFunctions]\nPublic = false"
},

]}
