# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
#
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
  Server.find_or_create_by_name(server[:name], :path => server[:path], :ip => server[:ip], :port => server[:port])
end
