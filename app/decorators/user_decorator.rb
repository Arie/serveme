# typed: true
# frozen_string_literal: true

class UserDecorator < Draper::Decorator
  extend T::Sig
  include Draper::LazyHelpers
  delegate_all

  sig { returns(T.nilable(String)) }
  def nickname
    if object.donator?
      h.tag.span h.safe_join([ object.nickname, " ", donator_icon ]), class: "donator"
    else
      object.nickname
    end
  end

  private

  sig { returns(String) }
  def donator_icon
    h.tag.icon "".html_safe, class: "fa fa-star", title: "Premium"
  end
end
