class TF2LineParser::Events::DamageDecorator < TF2LineParser::PlayerEventDecorator

  def text
    "#{player.name} did #{value} damage"
  end

end
