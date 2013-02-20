class TF2LineParser::Events::CurrentScoreDecorator < TF2LineParser::EventDecorator

  def text
    "#{team}'s score is #{score}"
  end

  def table_class
    "success"
  end

end
