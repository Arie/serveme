# typed: true
# frozen_string_literal: true

class MtrRunWorker
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: "low"

  BROADCAST_INTERVAL = 1.0
  RAW_OUTPUT_LIMIT = 200.kilobytes
  TIMEOUT_EXIT_STATUS = 124
  COMMAND_NOT_FOUND_EXIT_STATUS = 127

  def perform(mtr_run_id)
    @run = MtrRun.find(mtr_run_id)
    return if @run.finished?

    @trace = @run.mtr_trace
    source = @run.source
    return finish("failed", error: "This machine is no longer an active SSH or Docker host.") unless source
    return finish("failed", error: "Another trace is already running from this machine.") unless acquire_lock

    begin
      trace_from(source)
    ensure
      release_lock
    end
  end

  private

  def trace_from(source)
    @parser = MtrRawParser.new(target: @trace.target_ip)
    @enricher = MtrHopEnricher.new
    @raw = +""
    @stderr = +""
    @buffer = +""
    @last_broadcast = 0.0

    update_status("connecting")
    exit_status = source.stream(@trace.command) { |stream, data| stream == :stdout ? consume(data) : @stderr << data }
    @parser << @buffer unless @buffer.empty?

    status, error = outcome(exit_status)
    finish(status, error: error)
  rescue *SshExecution::SSH_RECOVERABLE_ERRORS, Net::SSH::AuthenticationFailed, SocketError => e
    finish(@run.status == "connecting" ? "unreachable" : "failed", error: "#{e.class}: #{e.message}")
  rescue StandardError => e
    Rails.logger.error "MtrRunWorker: run #{@run.id} failed: #{e.class}: #{e.message}"
    finish("failed", error: "#{e.class}: #{e.message}")
  end

  def consume(data)
    update_status("running") if @run.status == "connecting"
    @raw << data if @raw.bytesize < RAW_OUTPUT_LIMIT
    @buffer << data
    while (newline = @buffer.index("\n"))
      @parser << @buffer.slice!(0..newline)
    end
    return if monotonic - @last_broadcast < BROADCAST_INTERVAL

    @last_broadcast = monotonic
    @run.update!(hops: hops(final: false))
    broadcast
  end

  def outcome(exit_status)
    return [ "done", nil ] if exit_status&.zero?
    return [ "failed", "mtr is not installed on this machine (apt-get install mtr-tiny)." ] if exit_status == COMMAND_NOT_FOUND_EXIT_STATUS
    return [ "failed", "Timed out after #{@trace.cycles + 30}s; showing what arrived." ] if exit_status == TIMEOUT_EXIT_STATUS

    [ "failed", @stderr.strip.presence&.truncate(250) || "mtr exited with status #{exit_status.inspect}" ]
  end

  def finish(status, error: nil)
    attrs = { status: status, error: error, finished_at: Time.current }
    attrs.merge!(hops: hops(final: true), raw_output: @raw) if @parser
    @run.update!(attrs)
    broadcast
  end

  def update_status(status)
    @run.update!(status: status, started_at: @run.started_at || Time.current)
    broadcast
  end

  def hops(final:)
    @parser.hops(final: final).map do |hop|
      hop.except(:ips).merge(hosts: hop[:ips].map { |ip| @enricher.host(ip) }).deep_stringify_keys
    end
  end

  def broadcast
    @run.broadcast_detail
    @trace.broadcast_overview
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def lock_key
    "mtr_run:#{@run.source_type}:#{@run.source_key}"
  end

  def acquire_lock
    Sidekiq.redis { |conn| conn.set(lock_key, @run.id, nx: true, ex: @trace.cycles + 60) }
  end

  def release_lock
    Sidekiq.redis { |conn| conn.del(lock_key) }
  end
end
