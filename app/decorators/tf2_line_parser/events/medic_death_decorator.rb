class TF2LineParser::Events::MedicDeathDecorator < TF2LineParser::PvpEventDecorator

  decorates_association :target, with: TF2LineParser::MedicDecorator

  def text
    "#{player.name} killed medic #{target.name}"
  end

  def table_class
    "error"
  end

end
