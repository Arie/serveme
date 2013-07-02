class UserDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def nickname
    if donator?
      (source.nickname + '&nbsp;' + donator_icon).html_safe
    else
      source.nickname
    end
  end

  def donator_icon
    content_tag(:icon, "".html_safe, :class => "icon-star", :title => "Donator")
  end

end
