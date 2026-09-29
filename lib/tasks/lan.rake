# typed: false
# frozen_string_literal: true

# Used by script/lan-quickstart. Both tasks are safe to run more than once.
namespace :lan do
  desc "Register this machine as the docker host that runs the game servers (LAN_IP, DOCKER_SSH_USER, MAX_CONTAINERS)"
  task setup: :environment do
    lan_ip = ENV.fetch("LAN_IP")
    location = Location.find_or_create_by!(name: "LAN") { |l| l.flag = "europeanunion" }

    docker_host = DockerHost.find_or_initialize_by(hostname: lan_ip)
    docker_host.update!(
      ip: lan_ip,
      city: ENV.fetch("LAN_NAME", "LAN"),
      location: location,
      ssh_user: ENV.fetch("DOCKER_SSH_USER"),
      ssh_port: ENV.fetch("DOCKER_SSH_PORT", 22).to_i,
      max_containers: ENV.fetch("MAX_CONTAINERS", 4).to_i,
      start_port: 27015,
      setup_status: "ready",
      runs_caddy: false,
      active: true
    )
    DockerHost.where.not(id: docker_host.id).update_all(active: false)
    puts "Docker host #{docker_host.hostname}: #{docker_host.ssh_user}@#{docker_host.ip}:#{docker_host.ssh_port}, max #{docker_host.max_containers} servers"
  end

  desc "Make a Steam user (STEAM_UID, a SteamID64) an admin, before or after their first login"
  task admin: :environment do
    uid = ENV.fetch("STEAM_UID")
    abort "STEAM_UID must be a SteamID64 (7656...)" unless uid.match?(/\A7656\d{13}\z/)

    user = User.find_or_create_by!(provider: User::STEAM_PROVIDER, uid: uid) do |u|
      u.name = uid
      u.nickname = uid
    end
    GroupUser.find_or_create_by!(user: user, group: Group.admin_group, expires_at: nil)
    puts "#{user.nickname} (#{uid}) is an admin"
  end
end
