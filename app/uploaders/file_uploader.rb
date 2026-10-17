# typed: true
# frozen_string_literal: true

class FileUploader < CarrierWave::Uploader::Base
  permissions 0o755

  # Not under public/: uploads must not be served by the web server. log/ is
  # a volume shared by the web and sidekiq containers in every destination.
  def root
    Rails.root.join(Rails.env.test? ? "tmp" : "log")
  end

  def store_dir
    "file_uploads/#{model.id}"
  end

  def move_to_cache
    true
  end

  def move_to_store
    true
  end

  def extension_allowlist
    %w[zip]
  end
end
