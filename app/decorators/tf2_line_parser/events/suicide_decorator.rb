class TF2LineParser::Events::SuicideDecorator < TF2LineParser::PlayerEventDecorator

  def text
    "#{player.name} suicided"
  end

  def table_class
    'warning'
  end

end
