class TF2LineParser::Events::RevengeDecorator < TF2LineParser::PvpEventDecorator

  def text
    "#{player.name} avenged himself versus #{target.name}"
  end

end
