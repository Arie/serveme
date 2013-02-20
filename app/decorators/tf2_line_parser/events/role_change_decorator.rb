class TF2LineParser::Events::RoleChangeDecorator < TF2LineParser::PlayerEventDecorator

  def text
    "#{player.name} changed role to #{role_text}"
  end

  def role_text
    return icon('icon-bolt')                  if scout?
    return icon('icon-double-angle-up')       if soldier?
    return icon('icon-fire')                  if pyro?
    return icon('icon-circle')                if demoman?
    return icon('icon-user')                  if heavyweapons?
    return icon('icon-wrench')                if engineer?
    return icon('icon-plus-sign')             if medic?
    return icon('icon-screenshot icon-large') if sniper?
    return icon('icon-minus-sign')            if spy?
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
