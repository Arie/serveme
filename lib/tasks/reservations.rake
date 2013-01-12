namespace :reservations do

  desc "end_past_reservations"
  task :end => :environment do
    past_reservations         = Reservation.where('ends_at < ? AND provisioned = ?', Time.now, true)
    unended_past_reservations = past_reservations.where('ended = ?', false)
    threads = unended_past_reservations.map do |reservation|
      thread = Thread.new do
        reservation.end_reservation
        ActiveRecord::Base.connection.close
      end
      thread
    end
    threads.each do |thread|
      thread.join(10)
    end
  end

  desc "start_active_reservations"
  task :start => :environment do
    now_reservations            = Reservation.where('starts_at < ?', Time.now)
    unstarted_now_reservations  = now_reservations.where('provisioned = ?', false)
    threads = unstarted_now_reservations.map do |reservation|
      thread = Thread.new do
        reservation.start_reservation
        ActiveRecord::Base.connection.close
      end
      thread
    end
    threads.each do |thread|
      thread.join(10)
    end

  end


end
