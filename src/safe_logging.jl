# safe logging, copied from GPUCompiler

using Logging

const STDERR_HAS_COLOR = Ref{Bool}(false)

# Prevent invalidation when packages define custom loggers
# Using invoke in combination with @nospecialize eliminates backedges to these methods
function _invoked_min_enabled_level(@nospecialize(logger))
    return invoke(Logging.min_enabled_level, Tuple{typeof(logger)}, logger)::LogLevel
end

# define safe loggers for use in generated functions (where task switches are not allowed)
for level in [:debug, :info, :warn, :error]
    @eval begin
        macro $(Symbol("safe_$level"))(ex...)
            macrocall = :(@placeholder $(ex...))
            # NOTE: `@placeholder` in order to avoid hard-coding @__LINE__ etc
            macrocall.args[1] = Symbol($"@$level")
            quote
                old_logger = global_logger()
                io = IOContext(Core.stderr, :color=>STDERR_HAS_COLOR[])
                min_level = _invoked_min_enabled_level(old_logger)
                global_logger(Logging.ConsoleLogger(io, min_level))
                ret = $(esc(macrocall))
                global_logger(old_logger)
                ret
            end
        end
    end
end
