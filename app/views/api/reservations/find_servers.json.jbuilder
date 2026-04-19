# frozen_string_literal: true

json.reservation do
  json.partial! "api/reservations/reservation", reservation: @reservation
end
json.actions do
  json.create api_reservations_url
end
json.servers(@servers.to_a + (@docker_hosts || []).to_a) do |item|
  if item.is_a?(DockerHost)
    json.id item.virtual_server_id
    json.name "#{item.city} (Docker)"
    json.flag item.location&.flag
    json.ip item.hostname
    json.port item.start_port.to_s
    json.ip_and_port "#{item.hostname}:#{item.start_port}"
    json.sdr false
    json.latitude item.latitude
    json.longitude item.longitude
  else
    json.partial! "servers/server", server: item
  end
end
json.server_configs do
  json.partial! "api/server_configs/list", server_configs: ServerConfig.active.ordered
end
json.whitelists do
  json.partial! "api/whitelists/list", whitelists: Whitelist.ordered
end
