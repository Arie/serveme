class ServerDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def name
    flag + source.name
  end

  def flag
    if flag_abbreviation
      h.content_tag(:span, "", :class => "flags flags-#{location.flag}", :title => location.name)
    else
      ""
    end
  end

  def flag_abbreviation
    if location
      location.flag
    end
  end

end
