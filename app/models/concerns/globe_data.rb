# typed: false
# frozen_string_literal: true

module GlobeData
  extend ActiveSupport::Concern

  def globe_server_data(servers_with_players)
    permanent_servers = Server.active.not_cloud.where.not(latitude: nil, longitude: nil)

    servers_with_players_hash = servers_with_players.to_h { |data| [ data[:server].id, data[:players] ] }

    docker_host_players = {}
    docker_host_active_containers = Hash.new(0)
    servers_with_players.each do |data|
      server = data[:server]
      next unless server.is_a?(CloudServer) && server.cloud_provider == "remote_docker" && server.cloud_location.present?

      docker_host_id = server.cloud_location.to_i
      docker_host_players[docker_host_id] ||= []
      docker_host_players[docker_host_id].concat(data[:players])
      docker_host_active_containers[docker_host_id] += 1 if data[:players].any?
    end

    all_server_data = permanent_servers.map do |server|
      players = servers_with_players_hash[server.id] || []
      { server: server, players: players }
    end

    DockerHost.active.where.not(latitude: nil, longitude: nil).find_each do |docker_host|
      players = docker_host_players[docker_host.id] || []
      virtual_server = OpenStruct.new(
        id: docker_host.virtual_server_id,
        name: "#{docker_host.city} Cloud",
        latitude: docker_host.latitude,
        longitude: docker_host.longitude,
        detailed_location: docker_host.city,
        max_containers: docker_host.max_containers,
        active_containers: docker_host_active_containers[docker_host.id]
      )
      all_server_data << { server: virtual_server, players: players }
    end

    all_server_data
  end
end
