class TF2LineParser::PlayerDecorator < Draper::Decorator
  include Draper::LazyHelpers

  delegate_all

  def name
    content_tag(:span, source.name, :class => team.downcase, :title => source.steam_id)
  end
end
