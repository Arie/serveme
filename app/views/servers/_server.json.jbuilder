# frozen_string_literal: true

json.id server.id
json.name server.name
json.flag server.location.flag if server.location
json.ip server.public_ip
json.port server.public_port
json.ip_and_port "#{server.public_ip}:#{server.public_port}"
json.sdr server.sdr
json.latitude server.latitude
json.longitude server.longitude
