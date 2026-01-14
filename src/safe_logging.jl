# safe logging, copied from GPUCompiler

using Logging: Logging, @debug, @info, @warn, @error, LogLevel, global_logger

# Prevent invalidation when packages define custom loggers
# Using invoke in combination with @nospecialize eliminates backedges to these methods
function _invoked_min_enabled_level(@nospecialize(logger))
    return invoke(Logging.min_enabled_level, Tuple{typeof(logger)}, logger)::LogLevel
end

# define safe loggers for use in generated functions (where task switches are not allowed)
for level in [:debug, :info, :warn, :error]
    @eval begin
        macro $(Symbol("safe_$level"))(ex...)
            macrocall = :(@placeholder $(ex...) _file=$(String(__source__.file)) _line=$(__source__.line))
            # NOTE: `@placeholder` in order to avoid hard-coding @__LINE__ etc
            macrocall.args[1] = Symbol($"@$level")
            quote
                io = IOContext(Core.stderr, :color=>get(stderr, :color, false))
                # ideally we call Logging.shouldlog() here, but that is likely to yield,
                # so instead we rely on the min_enabled_level of the logger.
                # in the case of custom loggers that may be an issue, because,
                # they may expect Logging.shouldlog() getting called, so we use
                # the global_logger()'s min level which is more likely to be usable.
                min_level = _invoked_min_enabled_level(global_logger())
                safe_logger = Logging.ConsoleLogger(io, min_level)
                # using with_logger would create a closure, which is incompatible with
                # generated functions, so instead we reproduce its implementation here
                safe_logstate = Base.CoreLogging.LogState(safe_logger)
                @static if VERSION < v"1.11-"
                    t = current_task()
                    old_logstate = t.logstate
                    try
                        t.logstate = safe_logstate
                        $(esc(macrocall))
                    finally
                        t.logstate = old_logstate
                    end
                else
                    Base.ScopedValues.@with(
                        Base.CoreLogging.CURRENT_LOGSTATE => safe_logstate, $(esc(macrocall))
                    )
                end
            end
        end
    end
end
