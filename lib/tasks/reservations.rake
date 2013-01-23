namespace :reservations do

  desc "end_past_reservations"
  task :end => :environment do
    past_reservations         = Reservation.where('ends_at < ? AND provisioned = ?', Time.now, true)
    unended_past_reservations = past_reservations.where('ended = ?', false)
    unended_past_reservations.map do |reservation|
      reservation.end_reservation
    end
  end

  desc "start_active_reservations"
  task :start => :environment do
    now_reservations            = Reservation.where('starts_at < ?', Time.now)
    unstarted_now_reservations  = now_reservations.where('provisioned = ?', false)
    unstarted_now_reservations.map do |reservation|
      reservation.start_reservation
    end
  end


end
