using Logging
using ResumableFunctions
using Test

mutable struct CaptureLogger <: AbstractLogger
  records::Vector{NamedTuple}
end

Logging.min_enabled_level(::CaptureLogger) = Logging.Debug
Logging.shouldlog(::CaptureLogger, _level, _module, _group, _id) = true
Logging.catch_exceptions(::CaptureLogger) = false

function Logging.handle_message(
  logger::CaptureLogger,
  level,
  message,
  _module,
  group,
  id,
  file,
  line;
  kwargs...,
)
  push!(logger.records, (; level, message, group, metadata=(; kwargs...)))
end

@resumable function logging_generator()
  round = 3
  pair_id = 7
  attempts = 2
  @debug(
    "Logging from a resumable function",
    _group=:protocol,
    event=:round_started,
    round=round,
    pair_id,
    attempts,
  )
  @yield round
end

@resumable function qualified_logging_generator()
  value = 4
  Logging.@info(
    "Qualified logging macro",
    _group=:qualified,
    event=:qualified_record,
    value,
  )
  @logmsg(
    Logging.Warn,
    "Logging with an explicit level",
    _group=:logmsg,
    event=:logmsg_record,
    value,
  )
  @yield value
end

@testset "structured logging metadata" begin
  logger = CaptureLogger(NamedTuple[])
  values = Logging.with_logger(logger) do
    collect(logging_generator())
  end

  @test values == [3]
  @test length(logger.records) == 1
  record = only(logger.records)
  @test record.level == Logging.Debug
  @test record.message == "Logging from a resumable function"
  @test record.group == :protocol
  @test record.metadata == (
    event=:round_started,
    round=3,
    pair_id=7,
    attempts=2,
  )

  empty!(logger.records)
  values = Logging.with_logger(logger) do
    collect(qualified_logging_generator())
  end

  @test values == [4]
  @test length(logger.records) == 2
  qualified_record, logmsg_record = logger.records
  @test qualified_record.level == Logging.Info
  @test qualified_record.group == :qualified
  @test qualified_record.metadata == (event=:qualified_record, value=4)
  @test logmsg_record.level == Logging.Warn
  @test logmsg_record.group == :logmsg
  @test logmsg_record.metadata == (event=:logmsg_record, value=4)
end
