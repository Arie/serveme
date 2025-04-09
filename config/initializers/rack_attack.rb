# typed: strict
# frozen_string_literal: true

module Rack
  class Attack
    throttle("req/ip", limit: 300, period: 5.minutes, &:ip)
  end
end
