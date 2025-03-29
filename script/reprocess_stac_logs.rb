#!/usr/bin/env ruby
# typed: false
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
        <meta charset="utf-8">
        <link href="https://unpkg.com/tabulator-tables@5.5.2/dist/css/tabulator.min.css" rel="stylesheet">
        <script type="text/javascript" src="https://unpkg.com/tabulator-tables@5.5.2/dist/js/tabulator.min.js"></script>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.4; margin: 0 auto; padding: 20px; font-size: 14px; max-width: 1400px; }
          .search { margin: 10px 0; }
          input[type="text"] { padding: 8px; width: 300px; border: 1px solid #ddd; border-radius: 4px; }
          .player-name { font-weight: 500; }
          .server-name { color: #0066cc; }
          .demo-info { color: #666; font-size: 12px; }
          .timeline { font-family: monospace; font-size: 12px; }
          .detections { color: #cc0000; }
          a { color: #0066cc; text-decoration: none; }
          a:hover { text-decoration: underline; }
          .tabulator { margin-top: 10px; }
          .tabulator-col { background: #f5f5f5 !important; }
        </style>
      </head>
      <body>
        <h1>STAC Detections Report</h1>
        <p>Generated on <%= Time.now %></p>
        <div class="search">
          <input type="text" id="filter" placeholder="Search all columns...">
        </div>
        <div id="detection-table"></div>

        <script>
          const tableData = [
            <% @detections_by_reservation.sort_by { |_, data| data[:time] }.reverse.each do |reservation_id, data| %>
              <% data[:detections].each do |steam_id64, detection_data| %>
                {
                  time: "<%= data[:time].strftime("%Y-%m-%d %H:%M") %>",
                  player: `<div class="player-name"><%= detection_data[:name].dup.force_encoding('UTF-8') %></div>
                          <a href="https://<%= SITE_HOST %>/league-request?steam_uid=<%= steam_id64 %>&cross_reference=1" target="_blank"><%= steam_id64 %></a>`,
                  server: "<%= data[:server].name %>",
                  detections: `<% detection_data[:detections].tally.each do |type, count| %>
                              <%= type.dup.force_encoding('UTF-8') %>: <strong><%= count %>x</strong><br>
                             <% end %>`,
                  demo_info: `<% if data[:demo_info][:filename] %>
                              <div class="demo-info">
                                <%= data[:demo_info][:filename] %><br>
                                <span class="timeline">
                                  <% ticks = data[:demo_timeline].values.first || [] %>
                                  Ticks: <%= ticks.first(10).join(', ') %>
                                  <% if ticks.size > 10 %>... (+<%= ticks.size - 10 %>)<% end %>
                                </span>
                              </div>
                             <% end %>`,
                  links: `<a href="https://<%= SITE_HOST %>/reservations/<%= data[:reservation].id %>" target="_blank">Reservation</a>
                         <% if data[:reservation].stac_logs.first&.id %>
                           <br><a href="https://<%= SITE_HOST %>/stac_logs/<%= data[:reservation].stac_logs.first.id %>" target="_blank">STAC Log</a>
                         <% end %>`
                },
              <% end %>
            <% end %>
          ];

          const table = new Tabulator("#detection-table", {
            data: tableData,
            layout: "fitColumns",
            columns: [
              {title: "Time", field: "time", sorter: "string", width: 150},
              {title: "Player", field: "player", sorter: "string", formatter: "html"},
              {title: "Server", field: "server", sorter: "string", formatter: "html"},
              {title: "Detections", field: "detections", formatter: "html"},
              {title: "Demo Info", field: "demo_info", formatter: "html"},
              {title: "Links", field: "links", formatter: "html", width: 100}
            ],
            initialSort: [{column: "time", dir: "desc"}]
          });

          // Add global search functionality
          document.getElementById("filter").addEventListener("keyup", function(e){
            table.setFilter("*", "like", e.target.value);
          });
        </script>
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

    # Write log contents to temp file with UTF-8 encoding
    log_file = File.join(tmp_dir, "stac_#{log.id}.log")
    content = log.contents.encode('UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: '?')
    File.write(log_file, content)

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
File.write(output_file, report.generate.force_encoding('UTF-8'))

puts "Done processing logs"
puts "Report generated at #{output_file}"
