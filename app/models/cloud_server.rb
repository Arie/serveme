# typed: true
# frozen_string_literal: true

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
      verify_host_key: :never)
  end

  sig { returns(T::Boolean) }
  def supports_mitigations?
    cloud_provider != "docker"
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

  def mark_ready!
    updated = self.class.where(id: id).where.not(cloud_status: "destroyed").update_all(cloud_status: "ready")
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

  def end_reservation(reservation)
    if reservation.provisioned?
      super
    else
      reservation.status_update("Cancelling cloud server")
    end
  end

  def self.build_for_location(provider_name, location_code, rcon:)
    provider_class = CloudProvider::PROVIDERS[provider_name]
    raise ArgumentError, "Unknown provider: #{provider_name}" unless provider_class

    location_info = provider_class.locations[location_code]
    raise ArgumentError, "Unknown location: #{location_code}" unless location_info

    location = Location.find_or_create_by!(name: "#{location_info[:name]}, #{location_info[:country]}") do |l|
      l.flag = location_info[:flag]
    end

    new(
      name: "#{location_info[:name]} (#{provider_name})",
      ip: "0.0.0.0",
      port: "27015",
      path: "/home/tf2/hlserver/tf2",
      rcon: rcon,
      cloud_provider: provider_name,
      cloud_status: "provisioning",
      cloud_location: location_code,
      cloud_ssh_port: 2222,
      cloud_created_at: Time.current,
      cloud_callback_token: SecureRandom.hex(32),
      location: location
    )
  end

  private

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
    "scp -O -T -P #{ssh_port} -l 200000 -i #{key_file} -o StrictHostKeyChecking=no -o BatchMode=yes"
  end

  sig { returns(String) }
  def scp_target
    "tf2@#{ip}"
  end

  def sftp_start(&block)
    Net::SFTP.start(ip, "tf2", port: cloud_ssh_port || 22, key_data: [ cloud_ssh_private_key ], keys_only: true, non_interactive: true, verify_host_key: :never, &block)
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
