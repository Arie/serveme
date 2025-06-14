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

    normalized_path = path.end_with?("/") ? path : "#{path}/"
    allowed_paths&.any? do |allowed_path|
      normalized_allowed = allowed_path.end_with?("/") ? allowed_path : "#{allowed_path}/"
      normalized_path.start_with?(normalized_allowed)
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
