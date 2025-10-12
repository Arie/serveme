# typed: false
# frozen_string_literal: true

require 'csv'

files = [ 'banned_steam_ids.csv', 'banned_ips.csv', 'vpn_ips.csv', 'whitelisted_steam_ids.csv', 'bad-asn-list.csv' ]

files.each do |file|
  begin
    table = CSV.parse(File.read(file), headers: true)

    puts "Sorting and de-dupping #{file}"

    # Process data first before opening file for writing
    sorted_rows = if file == 'bad-asn-list.csv'
      table.uniq { |r| r[0] }.sort_by { |r| [ r['ASN'].to_i, r['Entity'] ] }
    else
      table.uniq { |r| r[0] }.sort_by { |r| [ r['name'].downcase, r['reason'], r[0] ] }
    end

    # Only write to file after successful processing
    csv_options = { write_headers: true, headers: table.headers }
    csv_options[:force_quotes] = true if file == 'bad-asn-list.csv'

    CSV.open(file, 'w', **csv_options) do |csv|
      sorted_rows.each do |r|
        csv << r
      end
    end
  rescue => e
    puts "Error processing #{file}: #{e.message}"
    puts "File was not modified"
  end
end
