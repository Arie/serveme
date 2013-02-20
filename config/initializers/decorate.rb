TF2LineParser::Events::Event.types.each do |type|
  type.class_eval do
    include Draper::Decoratable
  end
end

TF2LineParser::Player.class_eval do
  include Draper::Decoratable
end
