# typed: false
# frozen_string_literal: true

namespace :reservation_players do
  desc "Backfill ASN data with bulk IP updates (RECOMMENDED - fastest method)"
  task backfill_asn_data_bulk: :environment do
    # Get distinct IPs that need ASN data
    scope = ReservationPlayer
      .where(asn_number: nil)
      .where.not(ip: nil)
      .without_sdr_ip
      .group(:ip)
      .pluck(:ip)

    total_ips = scope.count
    total_records_updated = 0
    ips_processed = 0
    ips_skipped = 0
    failed = 0

    puts "Starting bulk ASN backfill..."
    puts "Found #{total_ips} unique IPs to process"
    puts "These IPs represent #{ReservationPlayer.where(asn_number: nil).where.not(ip: nil).without_sdr_ip.count} total records"
    puts "Processing in batches of 100 IPs..."

    start_time = Time.now

    # Process IPs in batches
    scope.each_slice(100) do |ip_batch|
      batch_updates = []

      ip_batch.each do |ip|
        begin
          # Look up ASN data for this IP
          asn_data = ReservationPlayer.asn(ip)

          if asn_data
            batch_updates << {
              ip: ip,
              asn_number: asn_data.autonomous_system_number,
              asn_organization: asn_data.autonomous_system_organization,
              asn_network: asn_data.network.to_s
            }
          else
            ips_skipped += 1
          end
        rescue => e
          puts "Error looking up ASN for IP #{ip}: #{e.message}"
          failed += 1
        end
      end

      # Execute bulk updates for this batch
      unless batch_updates.empty?
        begin
          # Build and execute a single UPDATE for all records with these IPs
          batch_updates.each do |update|
            count = ReservationPlayer
              .where(ip: update[:ip])
              .where(asn_number: nil)
              .update_all(
                asn_number: update[:asn_number],
                asn_organization: update[:asn_organization],
                asn_network: update[:asn_network]
              )

            total_records_updated += count
            ips_processed += 1
          end
        rescue => e
          puts "Error executing batch update: #{e.message}"
          failed += batch_updates.size
        end
      end

      # Progress report
      if (ips_processed + ips_skipped + failed) % 1000 == 0
        elapsed = Time.now - start_time
        rate = (ips_processed + ips_skipped) / elapsed
        records_rate = total_records_updated / elapsed

        puts "IPs processed: #{ips_processed}, skipped: #{ips_skipped}, failed: #{failed}"
        puts "  Records updated: #{total_records_updated} (#{records_rate.round(0)} records/sec)"
        puts "  IP processing rate: #{rate.round(0)} IPs/sec"
        puts "  Remaining IPs: #{total_ips - ips_processed - ips_skipped - failed}"
      end
    end

    elapsed = Time.now - start_time

    puts "\n" + "="*60
    puts "Bulk ASN backfill complete in #{(elapsed / 60).round(2)} minutes!"
    puts "="*60
    puts "Unique IPs processed: #{ips_processed}"
    puts "IPs skipped (no ASN): #{ips_skipped}"
    puts "IPs failed: #{failed}"
    puts "Total records updated: #{total_records_updated}"
    puts "Average rate: #{(total_records_updated / elapsed).round(0)} records/sec"
    puts "Average IP rate: #{((ips_processed + ips_skipped) / elapsed).round(0)} IPs/sec"
  end

  desc "Check ASN backfill status"
  task asn_status: :environment do
    total = ReservationPlayer.count
    with_ip = ReservationPlayer.where.not(ip: nil).count
    with_asn = ReservationPlayer.where.not(asn_number: nil).count
    without_asn = ReservationPlayer.where(asn_number: nil).where.not(ip: nil).without_sdr_ip.count
    unique_ips_without_asn = ReservationPlayer.where(asn_number: nil).where.not(ip: nil).without_sdr_ip.distinct.pluck(:ip).count

    puts "="*60
    puts "ASN Backfill Status"
    puts "="*60
    puts "Total reservation players: #{total.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}"
    puts "Records with IP: #{with_ip.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}"
    puts "Records with ASN data: #{with_asn.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}"
    puts "Records still needing ASN: #{without_asn.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}"
    puts "Unique IPs still needing ASN: #{unique_ips_without_asn.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}"
    puts "Progress: #{((with_asn.to_f / with_ip) * 100).round(2)}%" if with_ip > 0
    puts "="*60
  end
end
