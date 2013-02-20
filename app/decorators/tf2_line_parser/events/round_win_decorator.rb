class TF2LineParser::Events::RoundWinDecorator < TF2LineParser::EventDecorator

  def text
    "Round won by #{team}"
  end

  def table_class
    "success"
  end

end
