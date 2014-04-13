json.reservation do
  json.partial! 'api/reservations/reservation', reservation: @reservation
  json.servers do
    json.partial! 'api/servers/list', servers: @servers
  end
  json.server_configs do
    json.partial! 'api/server_configs/list', server_configs: ServerConfig.ordered
  end
  json.whitelists do
    json.partial! 'api/whitelists/list', whitelists: Whitelist.ordered
  end
  json.actions do
    json.create api_reservations_url
  end
end
