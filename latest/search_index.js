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
    "text": "C# sharp style generators a.k.a. semi-coroutines for Julia.C# has a convenient way to create iterators using the yield return statement. The package ResumableFunctions provides the same functionality for the Julia language by introducing the @resumable and the @yield macros. These macros can be used to replace the Task switching functions produce and consume which were deprecated in Julia v0.6. Channels are the preferred way for inter-task communication in julia v0.6+, but their performance is subpar for iterator applications."
},

{
    "location": "index.html#Example-1",
    "page": "Home",
    "title": "Example",
    "category": "section",
    "text": "using ResumableFunctions\n\n@resumable function fibonnaci(n::Int)\n  a = 0\n  b = 1\n  for i in 1:n\n    @yield a\n    a, b = b, a+b\n  end\nend\n\nfor val in fibonnaci(10) \n  println(val) \nend\n\n# output\n\n0\n1\n1\n2\n3\n5\n8\n13\n21\n34"
},

{
    "location": "index.html#Installation-1",
    "page": "Home",
    "title": "Installation",
    "category": "section",
    "text": "ResumableFunctions is a registered package and can be installed by running:Pkg.add(\"ResumableFunctions\")"
},

{
    "location": "index.html#Authors-1",
    "page": "Home",
    "title": "Authors",
    "category": "section",
    "text": "Ben Lauwens, Royal Military Academy, Brussels, Belgium."
},

{
    "location": "index.html#License-1",
    "page": "Home",
    "title": "License",
    "category": "section",
    "text": "ResumableFunctions is licensed under the MIT \"Expat\" License."
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
    "location": "manual.html#Basic-usage-1",
    "page": "Manual",
    "title": "Basic usage",
    "category": "section",
    "text": "When a @resumable function is called, it continues where it left during the previous invocation:DocTestSetup = quote\n  using ResumableFunctions\n\n  @resumable function basic_example()\n    @yield \"Initial call\"\n    @yield \"Second call\"\n    \"Final call\"\n  end\nend@resumable function basic_example()\n  @yield \"Initial call\"\n  @yield \"Second call\"\n  \"Final call\"\nendjulia> basic_iterator = basic_example();\n\njulia> basic_iterator()\n\"Initial call\"\n\njulia> basic_iterator()\n\"Second call\"\n\njulia> basic_iterator()\n\"Final call\"DocTestSetup = nothingThe @yield can also be used without a return argument:DocTestSetup = quote\n  using ResumableFunctions\n\n  @resumable function basic_example()\n    @yield \"Initial call\"\n    @yield \n    \"Final call\"\n  end\nend@resumable function basic_example()\n  @yield \"Initial call\"\n  @yield \n  \"Final call\"\nendjulia> basic_iterator = basic_example();\n\njulia> basic_iterator()\n\"Initial call\"\n\njulia> basic_iterator()\n\njulia> basic_iterator()\n\"Final call\"DocTestSetup = nothingThe famous Fibonnaci sequence can easily be generated:DocTestSetup = quote\n  using ResumableFunctions\n\n  @resumable function fibonnaci()\n    a = 0\n    b = 1\n    while true\n      @yield a\n      a, b = b, a + b\n    end\n  end\nend@resumable function fibonnaci()\n  a = 0\n  b = 1\n  while true\n    @yield a\n    a, b = b, a + b\n  end\nendjulia> fib_iterator = fibonnaci();\n\njulia> fib_iterator()\n0\n\njulia> fib_iterator()\n1\n\njulia> fib_iterator()\n1\n\njulia> fib_iterator()\n2\n\njulia> fib_iterator()\n3\n\njulia> fib_iterator()\n5\n\njulia> fib_iterator()\n8DocTestSetup = nothingThe @resumable function can take arguments and the type of the return value can be specified:DocTestSetup = quote\n  using ResumableFunctions\n\n  @resumable function fibonnaci(n) :: Int\n    a = 0\n    b = 1\n    for i in 1:n\n      @yield a\n      a, b = b, a + b\n    end\n    a\n  end\nend@resumable function fibonnaci(n) :: Int\n  a = 0\n  b = 1\n  for i in 1:n\n    @yield a\n    a, b = b, a + b\n  end\n  a\nendjulia> fib_iterator = fibonnaci(3);\n\njulia> fib_iterator()\n0\n\njulia> fib_iterator()\n1\n\njulia> fib_iterator()\n1\n\njulia> fib_iterator()\n2\n\njulia> fib_iterator()\nERROR: @resumable function has stopped!DocTestSetup = nothingWhen the @resumable function returns normally an error will be thrown if called again."
},

{
    "location": "manual.html#Two-way-communication-1",
    "page": "Manual",
    "title": "Two-way communication",
    "category": "section",
    "text": "The caller can transmit a variable to the @resumable function by assigning a @yield statement to a variable:DocTestSetup = quote\n  using ResumableFunctions\n\n  @resumable function two_way()\n    name = @yield \"Who are you?\"\n    \"Hello, \" * name * \"!\"\n  end\nend@resumable function two_way()\n  name = @yield \"Who are you?\"\n  \"Hello, \" * name * \"!\"\nendjulia> hello = two_way();\n\njulia> hello()\n\"Who are you?\"\n\njulia> hello(\"Ben\")\n\"Hello, Ben!\"DocTestSetup = nothingWhen an Exception is passed to the @resumable function, it is thrown at the resume point:DocTestSetup = quote\n  using ResumableFunctions\n\n  @resumable function mouse()\n    try\n      @yield \"Here I am!\"\n    catch exc\n      return \"You got me!\"\n    end\n  end\n\n  struct Cat <: Exception end\nend@resumable function mouse()\n  try\n    @yield \"Here I am!\"\n  catch exc\n    return \"You got me!\"\n  end\nend\n\nstruct Cat <: Exception endjulia> catch_me = mouse();\n\njulia> catch_me()\n\"Here I am!\"\n\njulia> catch_me(Cat())\n\"You got me!\"DocTestSetup = nothing"
},

{
    "location": "manual.html#Iterator-interface-1",
    "page": "Manual",
    "title": "Iterator interface",
    "category": "section",
    "text": "The interator interface is implemented for a @resumable function:DocTestSetup = quote\n  using ResumableFunctions\n\n  @resumable function fibonnaci(n) :: Int\n    a = 0\n    b = 1\n    for i in 1:n\n      @yield a\n      a, b = b, a + b\n    end\n  end\nend@resumable function fibonnaci(n) :: Int\n  a = 0\n  b = 1\n  for i in 1:n\n    @yield a\n    a, b = b, a + b\n  end\nendjulia> for val in fibonnaci(10) println(val) end\n0\n1\n1\n2\n3\n5\n8\n13\n21\n34DocTestSetup = nothing"
},

{
    "location": "manual.html#Parametric-@resumable-functions-1",
    "page": "Manual",
    "title": "Parametric @resumable functions",
    "category": "section",
    "text": "Type parameters can be specified with a where clause:DocTestSetup = quote\n  using ResumableFunctions\n\n  @resumable function fibonnaci(a::N, b::N=a+one(N)) :: N where {N<:Number}\n    for i in 1:10\n      @yield a\n      a, b = b, a + b\n    end\n  end\nend@resumable function fibonnaci(a::N, b::N=a+one(N)) :: N where {N<:Number}\n  for i in 1:10\n    @yield a\n    a, b = b, a + b\n   end\nendjulia> for val in fibonnaci(0.0) println(val) end\n0.0\n1.0\n1.0\n2.0\n3.0\n5.0\n8.0\n13.0\n21.0\n34.0DocTestSetup = nothing"
},

{
    "location": "manual.html#Caveats-1",
    "page": "Manual",
    "title": "Caveats",
    "category": "section",
    "text": "In a try block only top level @yield statements are allowed.\nIn a finally block a @yield statement is not allowed.\nAn anonymous function can not contain a @yield statement.\nIf a FiniteStateMachineIterator object is used in more than one for loop, only the state variable is reinitialised. A @resumable function that alters its arguments will use the modified values as initial parameters."
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
    "text": "The macro @resumable transform a function definition into a finite state-machine, i.e. a callable type holding the state and references to the internal variables of the function and a constructor for this new type respecting the method signature of the original function definition. When calling the new type a modified version of the body of the original function definition is executed:a dispatch mechanism is inserted at the start to allow a non local jump to a label inside the body;\nthe @yield statement is replaced by a return statement and a label placeholder as endpoint of a non local jump;\nfor loops are transformed in while loops and\ntry-catch-finally-end expressions are converted in a sequence of try-catch-end expressions with at the end of the catch part a non local jump to a label that marks the beginning of the expressions in the finally part.The two last transformations are needed to overcome the limitations of the non local jump macros @goto and @label.The complete procedure is explained using the following example:@resumable function fibonnaci(n::Int)\n  a = 0\n  b = 1\n  for i in 1:n-1\n    @yield a\n    a, b = b, a + b\n  end\n  a\nend"
},

{
    "location": "internals.html#Split-the-definition-1",
    "page": "Internals",
    "title": "Split the definition",
    "category": "section",
    "text": "The function definition is split by MacroTools.splitdef in different parts, eg. :name, :body, :args, ..."
},

{
    "location": "internals.html#For-loops-1",
    "page": "Internals",
    "title": "For loops",
    "category": "section",
    "text": "for loops in the body of the function definition are transformed in equivalent while loops:begin\n  a = 0\n  b = 1\n  _iter = 1:n-1\n  _iterstate = start(_iter)\n  while !done(_iter, _iterstate)\n    i, _iterstate = next(_iter, _iterstate)\n    @yield a\n    a, b = b, a + b\n  end\n  a\nend"
},

{
    "location": "internals.html#Slots-1",
    "page": "Internals",
    "title": "Slots",
    "category": "section",
    "text": "The slots and their types in the function definition are recovered by running the code_typed function for the locally evaluated function definition:n :: Int64\na :: Int64\nb :: Int64\n_iter :: UnitRange{Int64}\n_iterstate :: Int64\ni :: Int64"
},

{
    "location": "internals.html#Type-definition-1",
    "page": "Internals",
    "title": "Type definition",
    "category": "section",
    "text": "A mutable struct is defined containing the state and the slots:mutable struct ##123 <: ResumableFunctions.FiniteStateMachineIterator\n      _state :: UInt8\n      n :: Int64\n      a :: Int64\n      b :: Int64\n      _iter :: UnitRange{Int64}\n      _iterstate :: Int64\n      i :: Int64 \n\n      function ##123(n::Int64)\n        fsmi = new()\n        fsmi._state = 0x00\n        fsmi.n = n\n        fsmi\n      end\n    end"
},

{
    "location": "internals.html#Call-definition-1",
    "page": "Internals",
    "title": "Call definition",
    "category": "section",
    "text": "A call function is constructed that creates the previously defined composite type. This function satisfy the calling convention of the original function definition and is returned from the macro:function fibonnaci(n::Int)\n  ##123(n)\nend"
},

{
    "location": "internals.html#Transformation-of-the-body-1",
    "page": "Internals",
    "title": "Transformation of the body",
    "category": "section",
    "text": "In 6 steps the body of the function definition is transformed into a finite state-machine."
},

{
    "location": "internals.html#Renaming-of-slots-1",
    "page": "Internals",
    "title": "Renaming of slots",
    "category": "section",
    "text": "The slots are replaced by references to the fields of the composite type:begin\n  _fsmi.a = 0\n  _fsmi.b = 1\n  _fsmi._iter = 1:n-1\n  _fsmi._iterstate = start(_fsmi._iter)\n  while !done(_fsmi._iter, _fsmi._iterstate)\n    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)\n    @yield _fsmi.a\n    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b\n  end\n  _fsmi.a\nend"
},

{
    "location": "internals.html#Two-way-communication-1",
    "page": "Internals",
    "title": "Two-way communication",
    "category": "section",
    "text": "All expressions of the form _fsmi.arg = @yield are transformed into:@yield\n_fsmi.arg = _arg"
},

{
    "location": "internals.html#Exception-handling-1",
    "page": "Internals",
    "title": "Exception handling",
    "category": "section",
    "text": "Exception handling is added to @yield:begin\n  _fsmi.a = 0\n  _fsmi.b = 1\n  _fsmi._iter = 1:n-1\n  _fsmi._iterstate = start(_fsmi._iter)\n  while !done(_fsmi._iter, _fsmi._iterstate)\n    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)\n    @yield _fsmi.a\n    _arg isa Exception && throw(_arg)\n    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b\n  end\n  _fsmi.a\nend"
},

{
    "location": "internals.html#Try-catch-finally-end-block-handling-1",
    "page": "Internals",
    "title": "Try catch finally end block handling",
    "category": "section",
    "text": "try-catch-finally-end expressions are converted in a sequence of try-catch-end expressions with at the end of the catch part a non local jump to a label that marks the beginning of the expressions in the finally part."
},

{
    "location": "internals.html#Yield-transformation-1",
    "page": "Internals",
    "title": "Yield transformation",
    "category": "section",
    "text": "The @yield statement is replaced by a return statement and a label placeholder as endpoint of a non local jump:begin\n  _fsmi.a = 0\n  _fsmi.b = 1\n  _fsmi._iter = 1:n-1\n  _fsmi._iterstate = start(_fsmi._iter)\n  while !done(_fsmi._iter, _fsmi._iterstate)\n    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)\n    _fsmi._state = 0x01\n    return _fsmi.a\n    @label _STATE_1\n    _fsmi._state = 0xff\n    _arg isa Exception && throw(_arg)\n    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b\n  end\n  _fsmi.a\nend"
},

{
    "location": "internals.html#Dispatch-mechanism-1",
    "page": "Internals",
    "title": "Dispatch mechanism",
    "category": "section",
    "text": "A dispatch mechanism is inserted at the start of the body to allow a non local jump to a label inside the body:begin\n  _fsmi_state == 0x00 && @goto _STATE_0\n  _fsmi_state == 0x01 && @goto _STATE_1\n  error(\"@resumable function has stopped!\")\n  @label _STATE_0\n  _fsmi._state = 0xff\n  _arg isa Exception && throw(_arg)\n  _fsmi.a = 0\n  _fsmi.b = 1\n  _fsmi._iter = 1:n-1\n  _fsmi._iterstate = start(_fsmi._iter)\n  while !done(_fsmi._iter, _fsmi._iterstate)\n    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)\n    _fsmi._state = 0x01\n    return _fsmi.a\n    @label _STATE_1\n    _fsmi._state = 0xff\n    _arg isa Exception && throw(_arg)\n    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b\n  end\n  _fsmi.a\nend"
},

{
    "location": "internals.html#Making-the-type-callable-1",
    "page": "Internals",
    "title": "Making the type callable",
    "category": "section",
    "text": "A function is defined with one argument _arg:function (_fsmi::##123)(_arg::Any=nothing)\n  _fsmi_state == 0x00 && @goto _STATE_0\n  _fsmi_state == 0x01 && @goto _STATE_1\n  error(\"@resumable function has stopped!\")\n  @label _STATE_0\n  _fsmi._state = 0xff\n  _arg isa Exception && throw(_arg)\n  _fsmi.a = 0\n  _fsmi.b = 1\n  _fsmi._iter = 1:n-1\n  _fsmi._iterstate = start(_fsmi._iter)\n  while !done(_fsmi._iter, _fsmi._iterstate)\n    _fsmi.i, _fsmi._iterstate = next(_fsmi._iter, _fsmi._iterstate)\n    _fsmi._state = 0x01\n    return _fsmi.a\n    @label _STATE_1\n    _fsmi._state = 0xff\n    _arg isa Exception && throw(_arg)\n    _fsmi.a, _fsmi.b = _fsmi.b, _fsmi.a + _fsmi.b\n  end\n  _fsmi.a\nend"
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
    "location": "library.html#ResumableFunctions.ResumableFunctions",
    "page": "Library",
    "title": "ResumableFunctions.ResumableFunctions",
    "category": "module",
    "text": "Main module for ResumableFunctions.jl – C# style generators a.k.a. semi-coroutines for Julia\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.@resumable-Tuple{Expr}",
    "page": "Library",
    "title": "ResumableFunctions.@resumable",
    "category": "macro",
    "text": "Macro that transforms a function definition in a finite-statemachine:\n\nDefines a new mutable struct that implements the iterator interface and is used to store the internal state.\nMakes this new type callable having following characteristics:\nimplementents the statements from the initial function definition but;\nreturns at a @yield statement and;\ncontinues after the @yield statement when called again.\nDefines a constructor function that respects the calling conventions of the initial function definition and returns an object of the new type.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.@yield",
    "page": "Library",
    "title": "ResumableFunctions.@yield",
    "category": "macro",
    "text": "Macro if used in a @resumable function that returns the expr otherwise throws an error.\n\n\n\n\n\n"
},

{
    "location": "library.html#Public-interface-1",
    "page": "Library",
    "title": "Public interface",
    "category": "section",
    "text": "Modules = [ResumableFunctions]\nPrivate = false"
},

{
    "location": "library.html#Base.IteratorSize-Union{Tuple{Type{T}}, Tuple{T}} where T<:ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "Base.IteratorSize",
    "category": "method",
    "text": "Implements the iteratorsize method of the iterator interface for a subtype of FiniteStateMachineIterator.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.BoxedUInt8",
    "page": "Library",
    "title": "ResumableFunctions.BoxedUInt8",
    "category": "type",
    "text": "Mutable struct that contains a single UInt8.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "ResumableFunctions.FiniteStateMachineIterator",
    "category": "type",
    "text": "Abstract type used as base type for the type created by the @resumable macro.\n\n\n\n\n\n"
},

{
    "location": "library.html#Base.done-Union{Tuple{T}, Tuple{T}, Tuple{T,UInt8}} where T<:ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "Base.done",
    "category": "method",
    "text": "Implements the done method of the iterator interface for a subtype of FiniteStateMachineIterator.\n\n\n\n\n\n"
},

{
    "location": "library.html#Base.eltype-Union{Tuple{Type{T}}, Tuple{T}, Tuple{R}} where T<:ResumableFunctions.FiniteStateMachineIterator{R} where R",
    "page": "Library",
    "title": "Base.eltype",
    "category": "method",
    "text": "Implements the eltype method of the iterator interface for a subtype of FiniteStateMachineIterator.\n\n\n\n\n\n"
},

{
    "location": "library.html#Base.next-Union{Tuple{T}, Tuple{T,UInt8}} where T<:ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "Base.next",
    "category": "method",
    "text": "Implements the next method of the iterator interface for a subtype of FiniteStateMachineIterator.\n\n\n\n\n\n"
},

{
    "location": "library.html#Base.start-Union{Tuple{T}, Tuple{T}} where T<:ResumableFunctions.FiniteStateMachineIterator",
    "page": "Library",
    "title": "Base.start",
    "category": "method",
    "text": "Implements the start method of the iterator interface for a subtype of FiniteStateMachineIterator.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions._is_yield-Tuple{Any}",
    "page": "Library",
    "title": "ResumableFunctions._is_yield",
    "category": "method",
    "text": "Function returning whether an expression is a @yield macro\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.get_args-Tuple{Dict}",
    "page": "Library",
    "title": "ResumableFunctions.get_args",
    "category": "method",
    "text": "Function returning the arguments of a function definition\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.get_param_name-Tuple{Any}",
    "page": "Library",
    "title": "ResumableFunctions.get_param_name",
    "category": "method",
    "text": "Function returning the name of a where parameter\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.get_slots-Tuple{Dict,Dict{Symbol,Any},Module}",
    "page": "Library",
    "title": "ResumableFunctions.get_slots",
    "category": "method",
    "text": "Function returning the slots of a function definition\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.hasreturnvalue-Tuple{Any}",
    "page": "Library",
    "title": "ResumableFunctions.hasreturnvalue",
    "category": "method",
    "text": "Function checking the use of a return statement with value\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.make_arg_any-Tuple{Any,Dict{Symbol,Any}}",
    "page": "Library",
    "title": "ResumableFunctions.make_arg_any",
    "category": "method",
    "text": "Function changing the type of a slot arg of a arg = @yield ret or arg = @yield statement to Any.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.make_args-Tuple{Dict}",
    "page": "Library",
    "title": "ResumableFunctions.make_args",
    "category": "method",
    "text": "Function returning the args for the type construction.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.remove_catch_exc-Tuple{Any,Dict{Symbol,Any}}",
    "page": "Library",
    "title": "ResumableFunctions.remove_catch_exc",
    "category": "method",
    "text": "Function removing the exc symbol of a catch exc statement of a list of slots.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_arg-Tuple{Any}",
    "page": "Library",
    "title": "ResumableFunctions.transform_arg",
    "category": "method",
    "text": "Function that replaces a arg = @yield ret statement by \n\n  @yield ret; \n  arg = arg_\n\nwhere arg_ is the argument of the function containing the expression.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_exc-Tuple{Any}",
    "page": "Library",
    "title": "ResumableFunctions.transform_exc",
    "category": "method",
    "text": "Function that replaces a @yield ret or @yield statement by \n\n  @yield ret\n  _arg isa Exception && throw(_arg)\n\nto allow that an Exception can be thrown into a @resumable function.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_for-Tuple{Any,ResumableFunctions.BoxedUInt8}",
    "page": "Library",
    "title": "ResumableFunctions.transform_for",
    "category": "method",
    "text": "Function that replaces a for loop by a corresponding while loop saving explicitely the iterator and its state.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_let-Tuple{Any,Set{Symbol}}",
    "page": "Library",
    "title": "ResumableFunctions.transform_let",
    "category": "method",
    "text": "Function that replaces a variable _fsmi.x in an expression by x where x is a variable declared in a let block.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_slots-Tuple{Any,Base.KeySet{Symbol,Dict{Symbol,Any}}}",
    "page": "Library",
    "title": "ResumableFunctions.transform_slots",
    "category": "method",
    "text": "Function that replaces a variable x in an expression by _fsmi.x where x is a known slot.\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_slots_let-Tuple{Expr,Base.KeySet{Symbol,Dict{Symbol,Any}}}",
    "page": "Library",
    "title": "ResumableFunctions.transform_slots_let",
    "category": "method",
    "text": "Function that handles let block\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_try-Tuple{Any,ResumableFunctions.BoxedUInt8}",
    "page": "Library",
    "title": "ResumableFunctions.transform_try",
    "category": "method",
    "text": "Function that replaces a try-catch-finally-end expression having a top level @yield statement in the try part\n\n  try\n    before_statements...\n    @yield ret\n    after_statements...\n  catch exc\n    catch_statements...\n  finally\n    finally_statements...\n  end\n\nwith a sequence of try-catch-end expressions:\n\n  try\n    before_statements...\n  catch\n    catch_statements...\n    @goto _TRY_n\n  end\n  @yield ret\n  try\n    after_statements...\n  catch\n    catch_statements...\n  end\n  @label _TRY_n\n  finally_statements...\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_yield-Tuple{Any,ResumableFunctions.BoxedUInt8}",
    "page": "Library",
    "title": "ResumableFunctions.transform_yield",
    "category": "method",
    "text": "Function that replaces a @yield ret or @yield statement with \n\n  _fsmi._state = n\n  return ret\n  @label _STATE_n\n  _fsmi._state = 0xff\n\n\n\n\n\n"
},

{
    "location": "library.html#ResumableFunctions.transform_yield-Tuple{Any}",
    "page": "Library",
    "title": "ResumableFunctions.transform_yield",
    "category": "method",
    "text": "Function that replaces a @yield ret or @yield statement with \n\n  return ret\n\n\n\n\n\n"
},

{
    "location": "library.html#Internals-1",
    "page": "Library",
    "title": "Internals",
    "category": "section",
    "text": "Modules = [ResumableFunctions]\nPublic = false"
},

]}
