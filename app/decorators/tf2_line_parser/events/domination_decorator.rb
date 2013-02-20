class TF2LineParser::Events::DominationDecorator < TF2LineParser::PvpEventDecorator

  def text
    "#{player.name} dominated #{target.name}"
  end

  def table_class
    "warning"
  end

end
