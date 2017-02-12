# frozen_string_literal: true
class AnnounceDonatorWorker
  include Sidekiq::Worker

  def perform(nickname, product_name)
    Server.active.each do |s|
      s.rcon_say("#{nickname} just donated to serveme.tf - #{product_name}! #{Order.monthly_goal_percentage.round} percent of our monthly server bills are now taken care of")
      s.rcon_disconnect
    end
  end
end
