class TF2LineParser::PvpEventDecorator < TF2LineParser::EventDecorator
  decorates_association :player
  decorates_association :target
end
