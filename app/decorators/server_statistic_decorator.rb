# frozen_string_literal: true
class ServerStatisticDecorator < Drape::Decorator
  include Drape::LazyHelpers
  delegate_all

  def cpu_usage
    source.cpu_usage.round
  end

  def traffic_in
    "#{source.traffic_in} KB/s"
  end

  def traffic_out
    "#{source.traffic_out} KB/s"
  end
end
