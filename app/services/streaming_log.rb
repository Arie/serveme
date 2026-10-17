# typed: true
# frozen_string_literal: true

# Streaming logs live in log/streaming/<logsecret>.log while fresh. CleanupWorker
# zstd-compresses older ones to <logsecret>.log.zst. Readers seek by byte offset
# and shell out to rg, so compressed logs get unpacked into log/streaming/unpacked
# on demand (shared between containers, pruned by CleanupWorker).
module StreamingLog
  extend T::Sig

  COMPRESS_AFTER_DAYS = 7
  UNPACKED_TTL_MINUTES = 24 * 60

  sig { returns(Pathname) }
  def self.dir
    Rails.root.join("log", "streaming")
  end

  sig { returns(Pathname) }
  def self.unpacked_dir
    dir.join("unpacked")
  end

  # Path to a plain-text copy of the log. Falls back to the (possibly
  # nonexistent) plain path, so callers keep their File.exist? checks.
  sig { params(logsecret: T.nilable(String)).returns(String) }
  def self.readable_path(logsecret)
    plain = dir.join("#{logsecret}.log")
    return plain.to_s if File.exist?(plain)

    compressed = dir.join("#{logsecret}.log.zst")
    return plain.to_s unless logsecret.present? && File.exist?(compressed)

    unpack(compressed, unpacked_dir.join("#{logsecret}.log")) || plain.to_s
  end

  sig { params(compressed: Pathname, target: Pathname).returns(T.nilable(String)) }
  def self.unpack(compressed, target)
    if File.exist?(target)
      FileUtils.touch(target)
      return target.to_s
    end

    FileUtils.mkdir_p(unpacked_dir)
    tmp = "#{target}.#{SecureRandom.hex(4)}.tmp"
    unless system("zstd", "-q", "-d", "-f", "-o", tmp, compressed.to_s)
      Rails.logger.error("StreamingLog: failed to unpack #{compressed}")
      return nil
    end

    File.rename(tmp, target)
    target.to_s
  ensure
    FileUtils.rm_f(tmp) if tmp
  end
end
