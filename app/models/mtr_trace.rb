# typed: true
# frozen_string_literal: true

class MtrTrace < ActiveRecord::Base
  extend T::Sig

  CYCLE_OPTIONS = [ 10, 30, 100 ].freeze
  MAX_SOURCES = 8

  belongs_to :user, optional: true
  has_many :runs, -> { order(:id) }, class_name: "MtrRun", dependent: :destroy, inverse_of: :mtr_trace

  before_validation :resolve_target

  validates :target, presence: true
  validates :target_ip, presence: { message: "could not be resolved to an IPv4 address" }, if: -> { T.bind(self, MtrTrace).target.present? }
  validates :cycles, inclusion: { in: CYCLE_OPTIONS }
  validate :source_count, on: :create

  scope :recent, -> { order(created_at: :desc) }

  # Returns the trace whether or not it saved. An unsaved one carries the validation errors.
  sig { params(target: T.nilable(String), cycles: T.untyped, sources: T::Array[MtrSource], user: T.nilable(User)).returns(MtrTrace) }
  def self.launch(target:, cycles:, sources:, user:)
    trace = new(target: target, cycles: cycles.to_i, user: user)
    sources.each do |source|
      trace.runs.build(source_type: source.type, source_key: source.key, source_label: source.label, source_detail: source.detail, source_flag: source.flag)
    end
    trace.runs.each { |run| MtrRunWorker.perform_async(run.id) } if trace.save
    trace
  end

  sig { returns(T::Boolean) }
  def finished?
    runs.all?(&:finished?)
  end

  sig { returns(MtrTraceAnalysis) }
  def analysis
    MtrTraceAnalysis.new(self)
  end

  sig { returns(String) }
  def requested_by
    user&.nickname || "API"
  end

  # Only the IPAddr-normalised target_ip reaches a remote shell.
  sig { returns(String) }
  def command
    "timeout #{cycles + 30} mtr --raw -n -c #{cycles.to_i} #{IPAddr.new(target_ip)}"
  end

  # Runs finish in separate worker processes, so a broadcast must never render
  # from this instance's cached association.
  sig { void }
  def broadcast_overview
    runs.reset
    BetaBroadcast.replace(self, target: "mtr-overview", partial: "admin/mtr_traces/overview", locals: { trace: self, analysis: analysis })
  end

  private

  sig { void }
  def source_count
    return if runs.size.between?(1, MAX_SOURCES)

    errors.add(:base, "Select between 1 and #{MAX_SOURCES} machines to run from")
  end

  sig { void }
  def resolve_target
    entered = target.to_s.strip
    self.target = entered
    self.target_ip = (ipv4_literal(entered) || ipv4_lookup(entered)).to_s
  end

  sig { params(value: String).returns(T.nilable(String)) }
  def ipv4_literal(value)
    ip = IPAddr.new(value)
    ip.ipv4? && ip.prefix == 32 ? ip.to_s : nil
  rescue IPAddr::Error
    nil
  end

  sig { params(hostname: String).returns(T.nilable(String)) }
  def ipv4_lookup(hostname)
    return unless hostname.match?(/\A[a-z0-9]([a-z0-9\-.]{0,251}[a-z0-9])?\z/i)

    record = Resolv::DNS.open { |dns| dns.getresources(hostname, Resolv::DNS::Resource::IN::A).first }
    T.cast(record, T.nilable(Resolv::DNS::Resource::IN::A))&.address&.to_s
  rescue Resolv::ResolvError
    nil
  end
end
