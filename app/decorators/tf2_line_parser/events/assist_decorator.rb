class TF2LineParser::Events::AssistDecorator < TF2LineParser::PvpEventDecorator

  def text
    "#{player.name} assisted #{target.name}"
  end

end
