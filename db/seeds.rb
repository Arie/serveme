# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
#
unless Server.all.any?
  fb1 = { :name => 'FakkelBrigade #1',
          :path => '/home/tf2/tf2-1',
          :ip   => 'fakkelbrigade.eu',
          :port => '27015'
        }
  fb2 = { :name => 'FakkelBrigade #2',
          :path => '/home/tf2/tf2-2',
          :ip   => 'fakkelbrigade.eu',
          :port => '27025'
        }
  fb4 = { :name => 'FakkelBrigade #4',
          :path => '/home/tf2/tf2-4',
          :ip   => 'fakkelbrigade.eu',
          :port => '27045'
        }
  servers = [fb1, fb2, fb4]

  servers.each do |server|
    LocalServer.find_or_create_by_name(server[:name], :path => server[:path], :ip => server[:ip], :port => server[:port])
  end
  puts "Seeded servers #{servers.join(', ')}" unless Rails.env.test?
end

unless ServerConfig.all.any?
  configs = ['etf2l', 'etf2l_6v6', 'etf2l_9v9', 'etf2l_6v6_5cp', 'etf2l_6v6_ctf', 'etf2l_6v6_stopwatch', 'etf2l_9v9_5cp', 'etf2l_9v9_ctf', 'etf2l_9v9_koth', 'etf2l_9v9_stopwatch', 'etf2l_ultiduo', 'etf2l_bball', 'ugc_HL_ctf', 'ugc_HL_koth', 'ugc_HL_standard', 'ugc_HL_stopwatch', 'ugc_HL_tugofwar']
  configs.each do |config|
    ServerConfig.create(:file => config)
  end
  puts "Seeded configs #{configs.join(', ')}" unless Rails.env.test?
end

unless Whitelist.all.any?
  whitelists = [ 'etf2l_whitelist_6thcup.txt', 'etf2l_whitelist_6v6.txt', 'etf2l_whitelist_9v9.txt', 'etf2l_whitelist_bball.txt', 'etf2l_whitelist_quickfix.txt', 'etf2l_whitelist_vanilla.txt', 'item_whitelist_ugc_HL.txt' ]
  whitelists.each do |whitelist|
    Whitelist.create(:file => whitelist)
  end
  puts "Seeded whitelists #{whitelists.join(', ')}" unless Rails.env.test?
end
