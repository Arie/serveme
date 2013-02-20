class TF2LineParser::EventDecorator < Draper::Decorator
  include Draper::LazyHelpers

  delegate_all
end
