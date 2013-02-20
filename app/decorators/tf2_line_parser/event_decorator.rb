class TF2LineParser::EventDecorator < Draper::Decorator
  include Draper::LazyHelpers

  delegate_all

  def time
    content_tag(:span, :class => 'time') do
      I18n.l(source.time, :format => :time)
    end
  end

  def table_class
    ""
  end

  def icon(klass)
    content_tag(:i, '', :class => klass) + icon_text
  end
end
