json.id server.id
json.name server.name
if server.location
  json.flag server.location.flag
end
json.ip server.ip
json.port server.port
json.ip_and_port "#{server.ip}:#{server.port}"
json.latitude server.latitude
json.longitude server.longitude
