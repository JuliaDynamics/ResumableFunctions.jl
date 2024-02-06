# News

## v0.6.7 - 2024-01-02

- Fix stack overflow errors by reverting the changes introduced in v0.6.6.

## v0.6.6 - 2023-10-08

- Significantly improved performance on Julia 1.10 and newer by more precise inference of slot types.

## v0.6.5 - 2023-09-06

- Fix to a performance regression originally introduced by `@yieldfrom`.

## v0.6.4 - 2023-08-08

- Docstrings now work with `@resumable` functions.
- Generated types in `@resumable` functions have clearer names for better debugging.
- Line-number nodes are preserved in `@resumable` functions for better debugging and code coverage.

## Changelog before moving to JuliaDynamics

* 2023: v0.6.3
  * Julia 1.6 or newer is required
  * introduction of `@yieldfrom` to delegate to another resumable function or iterator (similar to [Python's `yield from`](https://peps.python.org/pep-0380/))
  * resumable functions are now allowed to return values, so that `r = @yieldfrom f` also stores the return value of `f` in `r`

* 2023: v0.6.2 
  * Julia v1.10 compatibility fix
  * resumable functions can now dispatch on types

* 2021: v0.6.1
  * `continue` in loop works

* 2021: v0.6.0
  * introduction of `@nosave` to keep a variable out of the saved structure.
  * optimized `for` loop.

* 2020: v0.5.2 is Julia v1.6 compatible.

* 2019: v0.5.1
  * inference problem solved: force iterator next value to be of type `Union` of `Tuple` and `Nothing`.

* 2019: v0.5.0 is Julia v1.2 compatible.

* 2018: v0.4.2 prepare for Julia v1.1
  * better inference caused a problem;).
  * iterator with a specified `rtype` is fixed.

* 2018: v0.4.0 is Julia v1.0 compatible.

* 2018: v0.3.1 uses the new iteration protocol.
  * the new iteration protocol is used for a `@resumable function` based iterator.
  * the `for` loop transformation implements also the new iteration protocol.

* 2018: v0.3 is Julia v0.7 compatible.
  * introduction of `let` block to allow variables not te be persisted between `@resumable function` calls (EXPERIMENTAL).
  * the `eltype` of a `@resumable function` based iterator is its return type if specified, otherwise `Any`.

* 2018: v0.2 the iterator now behaves as a Python generator: only values that are explicitly yielded are generated; the return value is ignored and a warning is generated.

* 2017: v0.1 initial release that is Julia v0.6 compatible:
  * Introduction of the `@resumable` and the `@yield` macros.
  * A `@resumable function` generates a type that implements the [iterator](https://docs.julialang.org/en/stable/manual/interfaces/#man-interface-iteration-1) interface.
  * Parametric `@resumable functions` are supported.
