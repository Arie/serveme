# frozen_string_literal: true

class MonthlyDonationProgressAnnouncerWorker
  include Sidekiq::Worker

  def perform
    human_date = Date.today.strftime('%B %-d')

    Reservation.includes(:user, :server).current.each do |r|
      r.server&.rcon_say("Today is #{human_date}, this month's donations have paid for #{Order.monthly_goal_percentage.round} percent of our server bills. Please donate at #{SITE_HOST} to keep this service alive") unless r.user.donator?
      r.server&.rcon_disconnect
    end
  end
end
