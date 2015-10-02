namespace :donations do

  desc "calculate"
  task :calculate, [:donated_amount, :start_date, :end_date] => [:environment] do |t, args|
    donated_amount = args[:donated_amount].to_f
    start_time = Date.parse(args[:start_date]).beginning_of_day
    end_time = Date.parse(args[:end_date]).end_of_day
    reservations = Reservation.where(:starts_at => start_time..end_time)
    total_reservation_seconds = 0
    reservations.find_in_batches do |res|
      res.each do |r|
        total_reservation_seconds += r.duration
      end
    end

    active_server_ids = reservations.pluck(:server_id).uniq

    puts "=" * 100
    puts "Calculating donation shares from: #{start_time} - #{end_time}"
    puts "Total reservation seconds over this period: #{total_reservation_seconds}"
    puts "=" * 100


    Server.where(:id => active_server_ids).group(:ip).pluck(:ip).sort.each do |hostname|
      host_server_count = Server.where(:ip => hostname).count
      host_reservations = reservations.where(:server_id => Server.where(:ip => hostname))
      hostname_sum = host_reservations.to_a.sum(&:duration)
      hostname_share = hostname_sum / total_reservation_seconds.to_f
      puts "Hostname: #{hostname} (#{host_server_count} servers)"
      puts "Reservation seconds: #{hostname_sum}"
      puts "Share: #{(hostname_share * 100).round(2)}%"
      puts "Amount: #{(hostname_share * donated_amount).round(2)}"
      puts "=" * 50
    end

  end

end
