# typed: false
# frozen_string_literal: true

class AllowReservationPlayersWorker
  include Sidekiq::Worker

  sidekiq_options retry: 10, queue: "priority"

  def perform(reservation_id)
    reservation = Reservation.includes(:server).find(reservation_id)
    server = reservation.server
    return unless server.supports_mitigations?

    $lock.synchronize("mitigation-server-#{server.id}", retries: 7, initial_wait: 0.5, expiry: 30.seconds) do
      return if reservation.reload.ended?

      players_to_whitelist = reservation.reservation_players.where(whitelisted: false)
      return if players_to_whitelist.empty?

      iptables = "sudo iptables -w 5"
      chain_name = "serveme-#{server.port}"

      commands = players_to_whitelist.filter_map do |rp|
        if rp.duplicates.whitelisted.none?
          %(#{iptables} -I #{chain_name} 1 -t raw -s #{rp.ip} -j ACCEPT -m comment --comment "#{chain_name}-#{rp.steam_uid}")
        end
      end

      server.mitigation_ssh_exec(commands.join("; "), log_stderr: true) if commands.any?

      players_to_whitelist.update_all(whitelisted: true) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
