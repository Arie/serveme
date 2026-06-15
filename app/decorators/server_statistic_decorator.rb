# typed: true
# frozen_string_literal: true

class ServerStatisticDecorator < Draper::Decorator
  extend T::Sig
  include Draper::LazyHelpers
  delegate_all

  sig { returns(Integer) }
  def cpu_usage
    object.cpu_usage.round
  end

  sig { returns(String) }
  def traffic_in
    "#{object.traffic_in} KB/s"
  end

  sig { returns(String) }
  def traffic_out
    "#{object.traffic_out} KB/s"
  end
end
