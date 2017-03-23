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
          :port => '27015',
          :latitude  => 51,
          :longitude => 9
        }
  fb2 = { :name => 'FakkelBrigade #2',
          :path => '/home/tf2/tf2-2',
          :ip   => 'fakkelbrigade.eu',
          :port => '27025',
          :latitude  => 51,
          :longitude => 9
        }
  fb4 = { :name => 'FakkelBrigade #4',
          :path => '/home/tf2/tf2-4',
          :ip   => 'fakkelbrigade.eu',
          :port => '27045',
          :latitude  => 51,
          :longitude => 9
        }
  servers = [fb1, fb2, fb4]

  servers.each do |server|
    LocalServer.where(:name => server[:name], :path => server[:path], :ip => server[:ip], :port => server[:port], :latitude => server[:latitude], :longitude => server[:longitude]).first_or_create
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

unless Location.all.any?
  locations = [
                {:name => "Austria",        :flag => "at"},
                {:name => "Belgium",        :flag => "be"},
                {:name => "Canada",         :flag => "ca"},
                {:name => "Czech Republic", :flag => "cz"},
                {:name => "Denmark",        :flag => "dk"},
                {:name => "England",        :flag => "en"},
                {:name => "EU",             :flag => "europeanunion"},
                {:name => "Germany",        :flag => "de"},
                {:name => "Finland",        :flag => "fi"},
                {:name => "France",         :flag => "fr"},
                {:name => "Hungary",        :flag => "hu"},
                {:name => "Ireland",        :flag => "ie"},
                {:name => "Israel",         :flag => "il"},
                {:name => "Latvia",         :flag => "lt"},
                {:name => "Netherlands",    :flag => "nl"},
                {:name => "Norway",         :flag => "no"},
                {:name => "Russia",         :flag => "ru"},
                {:name => "Scotland",       :flag => "scotland"},
                {:name => "Spain",          :flag => "es"},
                {:name => "UK",             :flag => "uk"},
                {:name => "USA",            :flag => "us"}
              ]
  locations.each do |location|
    Location.where(:name => location[:name], :flag => location[:flag]).first_or_create
  end

  unless Group.all.any?
    Group.create!(:name => "Donators")
  end
end
