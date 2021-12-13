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
end
