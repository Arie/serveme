# frozen_string_literal: true
class ServerStatisticDecorator < Draper::Decorator
  include Draper::LazyHelpers
  delegate_all

  def cpu_usage
    object.cpu_usage.round
  end

  def traffic_in
    "#{object.traffic_in} KB/s"
  end

  def traffic_out
    "#{object.traffic_out} KB/s"
  end
end
