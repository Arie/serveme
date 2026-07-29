# typed: true
# frozen_string_literal: true

class FileUploader < CarrierWave::Uploader::Base
  permissions 0o755

  def move_to_cache
    true
  end

  def move_to_store
    true
  end

  def extension_white_list
    %w[zip]
  end

  # Workers re-read the stored zip, so two uploads of the same filename must
  # not share a path or an in-flight job picks up the newer one's contents.
  def filename
    "#{model.id}_#{super}"
  end
end
