# typed: false
# frozen_string_literal: true

require 'csv'

files = [ 'banned_steam_ids.csv', 'banned_ips.csv', 'vpn_ips.csv', 'whitelisted_steam_ids.csv' ]

files.each do |file|
  table = CSV.parse(File.read(file), headers: true)

  puts "Sorting and de-dupping #{file}"

  CSV.open(file, 'w', write_headers: true, headers: table.headers) do |csv|
    table.uniq { |r| r[0] }.sort_by { |r| [ r['name'].downcase, r['reason'], r[0] ] }.each do |r|
      csv << r
    end
  end
end
