#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path('../../config/environment', __FILE__)
require 'erb'

class HTMLReport
  def initialize
    @detections_by_reservation = {}
  end

  def add_detections(reservation, detections, demo_info, demo_timeline)
    @detections_by_reservation[reservation.id] = {
      reservation: reservation,
      detections: detections,
      demo_info: demo_info,
      demo_timeline: demo_timeline,
      server: reservation.server,
      time: reservation.created_at
    }
  end

  def generate
    template = ERB.new(<<~HTML)
      <!DOCTYPE html>
      <html>
      <head>
        <title>STAC Detections Report</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; max-width: 1200px; margin: 0 auto; padding: 20px; }
          .reservation { border: 1px solid #ddd; margin: 20px 0; padding: 20px; border-radius: 8px; }
          .detection { margin: 10px 0; padding: 10px; background: #f5f5f5; border-radius: 4px; }
          .demo-info { color: #666; }
          h2 { color: #333; }
          .server-info { color: #0066cc; }
          .timeline { font-family: monospace; }
          .steam-id { color: #666; }
          .count { font-weight: bold; color: #cc0000; }
        </style>
      </head>
      <body>
        <h1>STAC Detections Report</h1>
        <p>Generated on <%= Time.now %></p>
        <% @detections_by_reservation.sort_by { |_, data| data[:time] }.reverse.each do |_, data| %>
          <div class="reservation">
            <h2>
              Reservation #<%= data[:reservation].id %>
              <span class="server-info">(<%= data[:server].name %>)</span>
            </h2>
            <p>Time: <%= data[:time] %></p>

            <% if data[:demo_info][:filename] %>
              <div class="demo-info">
                <p>Demo: <%= data[:demo_info][:filename] %></p>
                <p>Latest tick: <%= data[:demo_info][:tick] %></p>
                <div class="timeline">
                  Demo timeline:<br>
                  <% data[:demo_timeline].each do |filename, ticks| %>
                    <%= filename %>: <%= ticks.join(', ') %><br>
                  <% end %>
                </div>
              </div>
            <% end %>

            <% data[:detections].each do |steam_id64, detection_data| %>
              <div class="detection">
                <h3><%= detection_data[:name] %></h3>
                <p class="steam-id">
                  SteamID: <a href="https://steamid.io/lookup/<%= steam_id64 %>" target="_blank"><%= steam_id64 %></a>
                </p>
                <p>Detections:</p>
                <ul>
                  <% detection_data[:detections].tally.each do |type, count| %>
                    <li><%= type %>: <span class="count"><%= count %>x</span></li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          </div>
        <% end %>
      </body>
      </html>
    HTML

    template.result(binding)
  end
end

class CollectingStacLogProcessor < StacLogProcessor
  def notify_detections(all_detections, demo_info, demo_timeline)
    @report.add_detections(@reservation, all_detections, demo_info, demo_timeline)
  end

  def initialize(reservation, report)
    super(reservation)
    @report = report
  end
end

start_date = Time.parse('2025-02-20')
logs = StacLog.joins(:reservation).where('reservations.created_at >= ?', start_date)

puts "Found #{logs.count} STAC logs to process"

report = HTMLReport.new

Dir.mktmpdir do |tmp_dir|
  logs.find_each.with_index do |log, index|
    puts "Processing log #{index + 1}/#{logs.count} from reservation #{log.reservation_id}"

    # Write log contents to temp file
    log_file = File.join(tmp_dir, "stac_#{log.id}.log")
    File.write(log_file, log.contents)

    # Process the log
    begin
      CollectingStacLogProcessor.new(log.reservation, report).process_logs(tmp_dir)
    rescue => e
      puts "Error processing log #{log.id} from reservation #{log.reservation_id}: #{e.message}"
    ensure
      FileUtils.rm_f(log_file)
    end
  end
end

output_file = Rails.root.join('tmp', "stac_report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.html")
File.write(output_file, report.generate)

puts "Done processing logs"
puts "Report generated at #{output_file}"
