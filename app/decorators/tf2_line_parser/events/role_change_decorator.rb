class TF2LineParser::Events::RoleChangeDecorator < TF2LineParser::PlayerEventDecorator

  def text
    "#{player.name} changed role to #{role_text}"
  end

  def role_text
    return icon('small_class_icons-scout')        if scout?
    return icon('small_class_icons-soldier')      if soldier?
    return icon('small_class_icons-pyro')         if pyro?
    return icon('small_class_icons-demoman')      if demoman?
    return icon('small_class_icons-heavyweapons') if heavyweapons?
    return icon('small_class_icons-engineer')     if engineer?
    return icon('small_class_icons-medic')        if medic?
    return icon('small_class_icons-sniper')       if sniper?
    return icon('small_class_icons-spy')          if spy?
  end

  def icon_text
    role
  end

  def table_class
    "warning"
  end

  class_eval do
    ['scout', 'soldier', 'pyro', 'demoman', 'heavyweapons', 'engineer', 'medic', 'sniper', 'spy'].each do |role|
      define_method("#{role}?") { source.role == role }
    end
  end

end
