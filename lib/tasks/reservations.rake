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
    now_reservations            = Reservation.current
    unstarted_now_reservations  = now_reservations.where('provisioned = ?', false)
    unstarted_now_reservations.map do |reservation|
      reservation.start_reservation
    end
  end

  desc "check_active_reservations"
  task :check => :environment do
    unended_now_reservations      = Reservation.current.where('ended = ?', false)
    provisioned_now_reservations  = unended_now_reservations.where('provisioned = ?', true)
    provisioned_now_reservations.map do |reservation|
      if reservation.server.occupied?
        reservation.inactive_minute_counter = 30
        reservation.save(:validate => false)
      else
        reservation.increment!(:inactive_minute_counter)
        if reservation.inactive_too_long?
          reservation.end_reservation
        end
      end
    end
  end

end
