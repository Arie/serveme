# frozen_string_literal: true

module Reservations
  class PluginsDisabledValidator < ActiveModel::Validator
    def validate(record)
      if record.enable_plugins? && !(record.user.donator? || record.enable_demos_tf?)
        record.errors.add(:enable_plugins, 'only donators can have plugins enabled')
      end
    end
  end
end
