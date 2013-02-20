class TF2LineParser::Events::PointCaptureDecorator < TF2LineParser::EventDecorator

  def text
    "#{team} capture #{cap_name}"
  end

  def table_class
    "success"
  end

end

