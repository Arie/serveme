json.reservation do
  json.starts_at Time.current
  json.ends_at Time.current + 2.hours
  json.actions do
    json.find_servers find_servers_api_reservations_url
  end
end
