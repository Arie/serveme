#encoding: utf-8
class TF2LineParser::Events::ChargeDeployedDecorator < TF2LineParser::PlayerEventDecorator

  def text
    "#{player.name} übercharged #{uber_icon}"
  end

  def uber_icon
    icon('icon-warning-sign')
  end

  def icon_text
    ''
  end

  def table_class
    "info"
  end

end
