class TF2LineParser::Events::PickupItemDecorator < TF2LineParser::PlayerEventDecorator

  def text
    "#{player.name} picked up #{item_text}"
  end

  def item_text
    return icon('icon-medkit')               if small_medkit?
    return icon('icon-medkit icon-large')    if medium_or_large_medkit?
    return icon('icon-briefcase')            if small_ammo?
    return icon('icon-briefcase icon-large') if (medium_ammo? || large_ammo?)
    item
  end

  def icon_text
    item
  end

  def small_ammo?
    item == 'ammopack_small'
  end

  def medium_ammo?
    dropped_ammo? || item == 'ammopack_medium'
  end

  def large_ammo?
    item == 'ammopack_large'
  end

  def dropped_ammo?
    item == 'tf_ammo_pack'
  end

  def small_medkit?
    item == 'medkit_small'
  end

  def medium_or_large_medkit?
    item == 'medkit_medium' || item == 'medkit_large'
  end

end
