class TF2LineParser::Events::SayDecorator < TF2LineParser::MessageDecorator

  def text
    "#{player.name} said: #{message_text}"
  end

end
