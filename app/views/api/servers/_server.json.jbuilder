# frozen_string_literal: true

json.id server.id
json.name server.name
if server.location_id
  json.location do
    json.partial! 'locations/location', location: server.location
  end
end
