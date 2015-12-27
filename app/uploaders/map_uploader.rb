# frozen_string_literal: true
class MapUploader < CarrierWave::Uploader::Base

  permissions 0755

  def store_dir
    MAPS_DIR
  end

  def move_to_cache
    true
  end

  def move_to_store
    true
  end

  def extension_white_list
    %w(bsp zip bz2)
  end

end
