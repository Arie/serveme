class TF2LineParser::MessageDecorator < TF2LineParser::EventDecorator

  def message_text
    icon('icon-comment')
  end

  def icon_text
    content_tag(:em, message)
  end

end
