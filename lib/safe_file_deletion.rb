# typed: strict
# frozen_string_literal: true

module SafeFileDeletion
  extend T::Sig

  ALLOWED_TEMP_PATTERNS = T.let([
    %r{\A/tmp/reservation-\d+\z},           # /tmp/reservation-123
    %r{\A/tmp/temp_dir_\d+\z},              # /tmp/temp_dir_12345 (from Dir.mktmpdir)
    %r{\A/.+/tf/temp_reservation_\d+\z}     # /path/to/server/tf/temp_reservation_123
  ].freeze, T::Array[Regexp])

  class InvalidPathError < StandardError; end

  sig { params(path: T.nilable(String)).void }
  def self.validate_temp_directory!(path)
    raise InvalidPathError, "Path cannot be nil or empty" if path.nil? || path.empty?

    expanded_path = File.expand_path(path)

    unless ALLOWED_TEMP_PATTERNS.any? { |pattern| expanded_path.match?(pattern) }
      raise InvalidPathError, "Path does not match allowed temp directory patterns: #{expanded_path}"
    end
  end

  sig { params(path: String).returns(T::Boolean) }
  def self.safe_remove_directory(path)
    validate_temp_directory!(path)

    return false unless File.exist?(path)
    return false unless File.directory?(path)

    begin
      FileUtils.rm_rf(path)
      Rails.logger.info("SafeFileDeletion: Successfully removed #{path}")
      true
    rescue StandardError => e
      Rails.logger.error("SafeFileDeletion: Error removing #{path}: #{e.message}")
      false
    end
  end

  sig { params(path: String).returns(T::Boolean) }
  def self.safe_remove_directory!(path)
    validate_temp_directory!(path)

    unless File.exist?(path)
      Rails.logger.warn("SafeFileDeletion: Path does not exist: #{path}")
      return false
    end

    unless File.directory?(path)
      raise InvalidPathError, "Path is not a directory: #{path}"
    end

    FileUtils.rm_rf(path)
    Rails.logger.info("SafeFileDeletion: Successfully removed #{path}")
    true
  rescue StandardError => e
    Rails.logger.error("SafeFileDeletion: Error removing #{path}: #{e.message}")
    raise
  end
end
