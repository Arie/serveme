cron '*/1 * * * *' do
  db do
    sleep 1
    end_past_reservations
    start_active_reservations
    check_active_reservations
  end
end

def db(&block)
  begin
    ActiveRecord::Base.connection_pool.clear_stale_cached_connections!
    yield block
  rescue Exception => e
    raise e
  ensure
    ActiveRecord::Base.connection.close if ActiveRecord::Base.connection
    ActiveRecord::Base.clear_active_connections!
  end
end

def end_past_reservations
  past_reservations         = Reservation.where('ends_at < ? AND provisioned = ?', Time.current, true)
  unended_past_reservations = past_reservations.where('ended = ?', false)
  unended_past_reservations.map do |reservation|
    reservation.end_reservation
  end
end

def start_active_reservations
  now_reservations            = Reservation.current
  unstarted_now_reservations  = now_reservations.where('provisioned = ?', false)
  unstarted_now_reservations.map do |reservation|
    reservation.start_reservation
  end
end

def check_active_reservations
  unended_now_reservations      = Reservation.current.where('ended = ?', false)
  provisioned_now_reservations  = unended_now_reservations.where('provisioned = ?', true)
  provisioned_now_reservations.map do |reservation|
    if reservation.server.occupied?
      reservation.update_column(:last_number_of_players, reservation.server.number_of_players)
      reservation.update_column(:inactive_minute_counter, 0)
      reservation.warn_nearly_over if reservation.nearly_over?
    else
      reservation.update_column(:last_number_of_players, 0)
      reservation.increment!(:inactive_minute_counter)
      if reservation.inactive_too_long?
        reservation.end_reservation
      end
    end
  end
end
