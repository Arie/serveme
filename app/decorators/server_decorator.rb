# typed: true
# frozen_string_literal: true

class ServerDecorator < Draper::Decorator
  extend T::Sig
  include Draper::LazyHelpers
  delegate_all

  sig { returns(String) }
  def name
    flag + object.name
  end

  sig { returns(String) }
  def flag
    if flag_abbreviation
      h.tag.span "", class: "flags flags-#{flag_abbreviation}", title: object.location.name
    else
      ""
    end
  end

  sig { returns(T.nilable(String)) }
  def flag_abbreviation
    object.location&.flag
  end
end
