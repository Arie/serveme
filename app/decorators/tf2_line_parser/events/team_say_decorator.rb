class TF2LineParser::Events::TeamSayDecorator < TF2LineParser::MessageDecorator

  def text
    "#{player.name} said in team chat: #{message_text}"
  end

end
