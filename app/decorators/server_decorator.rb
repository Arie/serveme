# frozen_string_literal: true
class ServerDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def name
    flag + object.name
  end

  def flag
    if flag_abbreviation
      tag.span "", class: "flags flags-#{flag_abbreviation}", title: location.name
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
