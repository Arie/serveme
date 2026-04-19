# frozen_string_literal: true

server_entries = @servers.map do |server|
  {
    id: server.id,
    name: server.name,
    flag: server.location&.flag,
    ip: server.public_ip,
    port: server.public_port,
    ip_and_port: "#{server.public_ip}:#{server.public_port}",
    resolved_ip: server.resolved_ip,
    sdr: server.sdr,
    latitude: server.latitude,
    longitude: server.longitude
  }
end

docker_host_entries = (@docker_hosts || []).map do |dh|
  {
    id: "dh-#{dh.id}",
    name: "#{dh.city} (#{dh.hostname})",
    flag: dh.location&.flag,
    ip: dh.hostname,
    port: dh.start_port,
    ip_and_port: "#{dh.hostname}:#{dh.start_port}"
  }
end

json.servers(docker_host_entries + server_entries)
