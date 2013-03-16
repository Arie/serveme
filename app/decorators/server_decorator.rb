class ServerDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def name
    flag + source.name
  end

  def flag
    if location
      h.content_tag(:span, "", :class => "flags-#{location.flag}")
    else
      ""
    end
  end

end
