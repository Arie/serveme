# frozen_string_literal: true

class UserDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def nickname
    if donator?
      tag.span "#{object.nickname} #{donator_icon}".html_safe, class: 'donator'
    else
      object.nickname
    end
  end

  private

  def donator_icon
    tag.icon ''.html_safe, class: 'fa fa-star', title: 'Premium'
  end
end
