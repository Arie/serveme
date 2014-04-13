class UserDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def nickname
    if donator?
      content_tag(:span, :class => "donator") do
        "#{source.nickname} #{donator_icon}".html_safe
      end
    else
      source.nickname
    end
  end

  private

  def donator_icon
    content_tag(:icon, "".html_safe, :class => "fa fa-star", :title => "Donator")
  end

end
