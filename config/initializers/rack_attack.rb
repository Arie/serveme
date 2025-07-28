# typed: strict
# frozen_string_literal: true

module Rack
  class Attack
    unless Rails.env.test?
      throttle("req/ip", limit: 300, period: 5.minutes, &:ip)
    end
  end
end
