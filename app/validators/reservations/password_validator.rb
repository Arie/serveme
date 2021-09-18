# frozen_string_literal: true

module Reservations
  class PasswordValidator < ActiveModel::Validator
    def validate(record)
      regex = %r/^[a-zA-Z!@\d\-\ #$^&*\/()_+}'|\\:<>?,.\[\]]*$/
      options[:fields].each do |field|
        value = record.send(field)
        next if value.blank? || value.match?(regex)

        record.errors.add(field, 'Invalid characters, e.g. ; or "')
      end
    end
  end
end
