# typed: true
# frozen_string_literal: true

require "open3"

class CloudServer < RemoteServer
  extend T::Sig
  include SshExecution

  CLOUD_STATUSES = %w[provisioning ssh_ready ready destroyed].freeze
  validates :cloud_status, inclusion: { in: CLOUD_STATUSES }, allow_nil: true

  sig { returns(T.nilable(Net::SSH::Connection::Session)) }
  def ssh
    @ssh ||= Net::SSH.start(ip, "tf2",
      port: cloud_ssh_port || 22,
      key_data: [ cloud_ssh_private_key ],
      keys_only: true,
      non_interactive: true,
      verify_host_key: :never,
      timeout: 5,
      keepalive: true,
      keepalive_interval: 5,
      keepalive_maxcount: 2)
  end

  sig { returns(T::Boolean) }
  def supports_mitigations?
    true
  end

  sig { params(command: String, log_stderr: T::Boolean).returns(String) }
  def mitigation_ssh_exec(command, log_stderr: false)
    case cloud_provider
    when "docker"
      out, err, = Open3.capture3(command)
      logger.info "STDERR while executing #{command}:\n#{err}" if log_stderr && err.present?
      out
    when "remote_docker"
      docker_host = DockerHost.find(T.must(cloud_location))
      out = []
      err = []
      Net::SSH.start(docker_host.ip, nil, timeout: 5, keepalive: true, keepalive_interval: 5, keepalive_maxcount: 2) do |ssh|
        ssh.exec!(command) do |_channel, stream, data|
          out << data if stream == :stdout
          err << data if stream == :stderr
        end
      end
      logger.info "SSH STDERR while executing #{command}:\n#{err.join("\n")}" if log_stderr && err.any?
      out.join("\n")
    else
      ssh_exec(command, log_stderr: log_stderr)
    end
  end

  sig { returns(T::Boolean) }
  def outdated?
    false
  end

  sig { returns(CloudProvider::Base) }
  def provider
    @provider ||= CloudProvider.for(T.must(cloud_provider))
  end

  def write_first_map(reservation)
    first_map = reservation.first_map.presence || "ctf_turbine"
    write_configuration(server_config_file("first_map.txt"), first_map)
  end

  sig { params(reservation: Reservation).returns(T.nilable(T::Hash[Symbol, T.untyped])) }
  def provision_estimate(reservation)
    phases = provider.provision_phases

    if reservation.provisioned?
      return cloud_status == "destroyed" ? nil : { phases: phases, completed: true }
    end

    return unless cloud_created_at.present?
    return if cloud_status == "destroyed"

    current_phase, phase_started_at = cloud_current_phase(reservation)
    result = {
      phases: phases,
      current_phase: current_phase,
      phase_started_at: phase_started_at
    }
    if current_phase == "creating_vm"
      vm_status = reservation.reservation_statuses.find_by("status LIKE 'Creating VM (%'")
      result[:vm_progress] = vm_status.status.to_s[/\((\d+)%\)/, 1]&.to_i if vm_status
    end
    result
  end

  def mark_ready!
    updated = self.class.where(id: id).where.not(cloud_status: "destroyed").update_all(cloud_status: "ready", active: true)
    return unless updated > 0

    reload
    broadcast_reservation_status
  end

  def broadcast_reservation_status
    reservation = Reservation.find_by(id: cloud_reservation_id)
    return unless reservation

    reservation.broadcast_replace_to reservation,
      target: "reservation_status_message_#{reservation.id}",
      partial: "reservations/status",
      locals: { reservation: reservation }
    reservation.broadcast_connect_info
  end

  def end_estimate(reservation)
    return if !reservation.provisioned?

    super
  end

  def end_reservation(reservation)
    if reservation.provisioned? && cloud_status != "destroyed"
      super
    else
      reservation.status_update("Cancelling cloud server")
    end
  end

  def self.next_available_port_for(cloud_provider, cloud_location)
    start_port = if cloud_provider == "remote_docker"
      T.must(DockerHost.find(cloud_location).start_port)
    else
      27015
    end
    used_ports = where(cloud_provider: cloud_provider, cloud_location: cloud_location)
      .where.not(cloud_status: "destroyed")
      .pluck(:port).map(&:to_i).to_set
    port = start_port
    port += 10 while used_ports.include?(port)
    port
  end

  def self.next_available_docker_port
    next_available_port_for("docker", "local")
  end

  def self.build_for_location(provider_name, location_code, rcon:)
    provider_class = CloudProvider::PROVIDERS[provider_name]
    raise ArgumentError, "Unknown provider: #{provider_name}" unless provider_class

    if provider_name == "remote_docker"
      docker_host = DockerHost.find(location_code)
      location = docker_host.location
      location_name = docker_host.city
    else
      location_info = provider_class.locations[location_code]
      raise ArgumentError, "Unknown location: #{location_code}" unless location_info

      location = Location.find_or_create_by!(name: "#{location_info[:name]}, #{location_info[:country]}") do |l|
        l.flag = location_info[:flag]
      end
      location_name = location_info[:name]
    end

    if provider_name.in?(%w[docker remote_docker])
      game_port = next_available_port_for(provider_name, location_code)
      start_port = provider_name == "remote_docker" ? T.must(T.must(docker_host).start_port) : 27015
      ssh_port = 22000 + (game_port - start_port) / 10
    else
      game_port = 27015
      ssh_port = 2222
    end

    attrs = {
      name: "#{location_name} (#{provider_name == "remote_docker" ? SITE_HOST : provider_name.titleize})",
      ip: "0.0.0.0",
      port: game_port.to_s,
      path: "/home/tf2/hlserver/tf2",
      rcon: rcon,
      active: false,
      cloud_provider: provider_name,
      cloud_status: "provisioning",
      cloud_location: location_code,
      cloud_ssh_port: ssh_port,
      cloud_created_at: Time.current,
      cloud_callback_token: SecureRandom.hex(32),
      location: location
    }

    if provider_name == "remote_docker" && T.must(docker_host).latitude && T.must(docker_host).longitude
      attrs[:latitude] = T.must(docker_host).latitude
      attrs[:longitude] = T.must(docker_host).longitude
    end

    new(attrs)
  end

  sig { returns(String) }
  def cloud_ssh_public_key
    key = Net::SSH::KeyFactory.load_data_private_key(cloud_ssh_private_key)
    "#{key.ssh_type} #{[ key.to_blob ].pack('m0')}"
  end

  private

  sig { params(reservation: Reservation).returns([ String, ActiveSupport::TimeWithZone ]) }
  def cloud_current_phase(reservation)
    if cloud_status == "ready"
      tf2_port_open = reservation.reservation_statuses.find_by("status LIKE 'TF2 port open%'")
      started_at = if tf2_port_open
        T.cast(tf2_port_open.created_at, ActiveSupport::TimeWithZone)
      else
        T.must(cloud_ssh_ready_at || cloud_created_at)
      end
      [ "starting_tf2", started_at ]
    elsif cloud_ssh_ready_at.present?
      configs_sent = reservation.reservation_statuses.find_by("status LIKE 'Config files sent%'")
      if configs_sent
        [ "booting_tf2", T.cast(configs_sent.created_at, ActiveSupport::TimeWithZone) ]
      else
        [ "configuring", T.must(cloud_ssh_ready_at) ]
      end
    elsif cloud_vm_running_at.present?
      [ "booting", T.must(cloud_vm_running_at) ]
    else
      [ "creating_vm", T.must(cloud_created_at) ]
    end
  end

  sig { returns(String) }
  def cloud_ssh_private_key
    cloud_ssh_private_key_from_file ||
      Rails.application.credentials.dig(:cloud_servers, :ssh_private_key)
  end

  sig { returns(T.nilable(String)) }
  def cloud_ssh_private_key_from_file
    path = Rails.root.join("tmp", "cloud_ssh_key")
    File.read(path) if File.exist?(path)
  end

  sig { returns(String) }
  def scp_command
    key_file = cloud_ssh_key_file
    ssh_port = cloud_ssh_port || 22
    "scp -O -T -P #{ssh_port} -l 200000 -i #{key_file} -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2"
  end

  sig { returns(String) }
  def scp_target
    "tf2@#{ip}"
  end

  def sftp_start(&block)
    Net::SFTP.start(ip, "tf2", port: cloud_ssh_port || 22, key_data: [ cloud_ssh_private_key ], keys_only: true, non_interactive: true, verify_host_key: :never, timeout: 5, &block)
  end

  sig { returns(String) }
  def cloud_ssh_key_file
    @cloud_ssh_key_file ||= begin
      key = cloud_ssh_private_key
      f = Tempfile.new("cloud_ssh_key")
      f.write(key)
      f.chmod(0o600)
      f.close
      @cloud_ssh_key_tempfile = f # prevent GC
      f.path
    end
  end
end
