# typed: true
# frozen_string_literal: true

class CloudImageBuildOutputStreamer
  extend T::Sig

  FLUSH_LINES = 20
  FLUSH_INTERVAL = 0.5
  MAX_BYTES = 2.megabytes
  TRUNCATION_MARKER = "[... earlier output truncated ...]\n"

  sig { params(build: CloudImageBuild).void }
  def initialize(build)
    @build = build
    @buffer = +""
    @line_count = 0
    @last_flush = Time.current
  end

  sig { params(text: String).void }
  def append(text)
    @buffer << text
    @line_count += text.count("\n")
    flush! if should_auto_flush?
  end

  sig { void }
  def flush!
    return if @buffer.empty?

    persist
    broadcast(@buffer)
    @buffer = +""
    @line_count = 0
    @last_flush = Time.current
  end

  private

  sig { returns(T::Boolean) }
  def should_auto_flush?
    @line_count >= FLUSH_LINES || (Time.current - @last_flush) >= FLUSH_INTERVAL
  end

  sig { void }
  def persist
    @build.reload
    combined = @build.output + @buffer
    if combined.bytesize > MAX_BYTES
      keep_bytes = MAX_BYTES - TRUNCATION_MARKER.bytesize
      tail = combined.byteslice(combined.bytesize - keep_bytes, keep_bytes) || ""
      newline_idx = tail.index("\n")
      tail = tail[(newline_idx + 1)..] if newline_idx
      @build.update_column(:output, TRUNCATION_MARKER + tail.to_s)
    else
      @build.update_column(:output, combined)
    end
  end

  sig { params(chunk: String).void }
  def broadcast(chunk)
    Turbo::StreamsChannel.broadcast_append_to(
      [ @build, "output" ],
      target: "build-output",
      html: ERB::Util.html_escape(chunk)
    )
  end
end
