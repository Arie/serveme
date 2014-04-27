json.id server.id
json.name server.name
json.location do
  json.partial! 'locations/location', location: server.location
end
