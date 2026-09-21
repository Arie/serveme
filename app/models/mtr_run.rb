# typed: true
# frozen_string_literal: true

class MtrRun < ActiveRecord::Base
  extend T::Sig

  STATUSES = %w[queued connecting running done failed unreachable].freeze
  TERMINAL_STATUSES = %w[done failed unreachable].freeze

  belongs_to :mtr_trace, inverse_of: :runs

  validates :status, inclusion: { in: STATUSES }
  validates :source_type, :source_key, :source_label, presence: true

  sig { returns(T::Boolean) }
  def finished?
    TERMINAL_STATUSES.include?(status)
  end

  sig { returns(T.nilable(MtrSource)) }
  def source
    MtrSource.find(source_type, source_key)
  end

  sig { returns(String) }
  def short_label
    T.must(source_label.split(".").first)
  end

  sig { returns(Integer) }
  def cycles_seen
    hops.map { |h| h["sent"].to_i }.max || 0
  end

  sig { void }
  def broadcast_detail
    trace = T.must(mtr_trace)
    trace.runs.reset
    BetaBroadcast.replace(trace, target: "mtr-run-#{id}", partial: "admin/mtr_traces/run", locals: { run: self, analysis: trace.analysis })
  end
end
