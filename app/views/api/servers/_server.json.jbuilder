json.id server.id
json.name server.name
json.location do
  json.partial! 'api/locations/location', location: server.location
end
