# frozen_string_literal: true

json.id server.id
json.name server.name
json.flag server.location.flag if server.location
json.ip server.ip
json.port server.port
json.ip_and_port "#{server.ip}:#{server.port}"
json.latitude server.latitude
json.longitude server.longitude
