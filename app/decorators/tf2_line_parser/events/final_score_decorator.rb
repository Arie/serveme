class TF2LineParser::Events::FinalScoreDecorator < TF2LineParser::EventDecorator

  def text
    "#{team}'s final score is #{score}"
  end

  def table_class
    "success"
  end

end
