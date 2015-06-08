class MonthlyDonationPorgressAnnouncerWorker

  include Sidekiq::Worker
  include Sidetiq::Schedulable

  recurrence { daily.hour_of_day(21).minute_of_hour(15) }

  def perform
    human_date = Date.today.strftime("%B %-d")

    Reservation.includes(:user, :server).current.each do |r|
      r.server.rcon_say("Today is #{human_date}, monthly donation goal is currently at #{PaypalOrder.monthly_goal_percentage.round}% Please donate at #{SITE_HOST} to keep this service alive") unless r.user.donator?
    end
  end

end
