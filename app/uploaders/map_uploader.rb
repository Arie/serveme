class MapUploader < CarrierWave::Uploader::Base

  permissions 0644

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
    %w(bsp)
  end

end
