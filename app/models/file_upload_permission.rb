# typed: true
# frozen_string_literal: true

class FileUploadPermission < ActiveRecord::Base
  extend T::Sig

  belongs_to :user

  validates :allowed_paths, presence: true
  validate :validate_paths_format

  sig { params(path: String).returns(T.nilable(T::Boolean)) }
  def path_allowed?(path)
    return false if allowed_paths.nil? || allowed_paths&.empty?

    allowed_paths&.any? do |allowed_path|
      if allowed_path.end_with?("/")
        # If allowed_path ends with /, it's a directory permission
        normalized_path = path.end_with?("/") ? path : "#{path}/"
        normalized_path.start_with?(allowed_path)
      else
        # If allowed_path doesn't end with /, it's a specific file permission
        path == allowed_path
      end
    end
  end

  private

  def validate_paths_format
    return if allowed_paths.blank?

    allowed_paths&.each do |path|
      unless path.match?(%r{^[a-zA-Z0-9_\.\-/]+$})
        errors.add(:allowed_paths, "contains invalid path format: #{path}")
        break
      end
    end
  end
end
