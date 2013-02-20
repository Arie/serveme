class TF2LineParser::Events::ConsoleSayDecorator < TF2LineParser::MessageDecorator

  def text
    "Console said: #{message_text}"
  end

end
