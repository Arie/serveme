class TF2LineParser::Events::CaptureBlockDecorator < TF2LineParser::PlayerEventDecorator

  def text
    "#{player.name} blocked #{cap_name}"
  end

end
