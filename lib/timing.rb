# typed: strict
# frozen_string_literal: true

module Timing
  extend T::Sig

  sig { returns(Float) }
  def self.now
    Float(Process.clock_gettime(Process::CLOCK_MONOTONIC))
  end

  sig { params(round: T.nilable(Integer), block: T.proc.void).returns(Float) }
  def self.measure(round: nil, &block)
    start = now
    yield
    duration = now - start
    if round
      T.cast(duration.round(round), Float)
    else
      duration
    end
  end
end
