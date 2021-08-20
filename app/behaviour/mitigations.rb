# frozen_string_literal: true

module Mitigations
  def anti_dos?
    true
  end

  def enable_mitigations
    return unless anti_dos?

    server.ssh_exec(
      %(
        sudo iptables -w #{xtables_timeout} -N #{chain_name} &&
        sudo iptables -w #{xtables_timeout} -A #{chain_name} -p tcp -m limit --limit 100/s --limit-burst 100 -j ACCEPT &&
        sudo iptables -w #{xtables_timeout} -A #{chain_name} -p udp -m limit --limit 300/s --limit-burst 300 -j ACCEPT &&
        sudo iptables -w #{xtables_timeout} -A #{chain_name} -j DROP &&
        sudo iptables -w #{xtables_timeout} -A INPUT -p udp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables -w #{xtables_timeout} -A INPUT -p tcp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables -w #{xtables_timeout} -I #{chain_name} 1 -s direct.#{SITE_HOST} -j ACCEPT -m comment --comment "#{chain_name}-system"
      ), log_stderr: true
    )
  end

  def disable_mitigations(log_stderr: true)
    return unless anti_dos?

    server.ssh_exec(
      %(
        sudo iptables -w #{xtables_timeout} -D INPUT -p udp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables -w #{xtables_timeout} -D INPUT -p tcp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables -w #{xtables_timeout} --flush #{chain_name} &&
        sudo iptables -w #{xtables_timeout} -X #{chain_name}
      ), log_stderr: log_stderr
    )
  end

  def allow_reservation_player(reservation_player)
    return unless anti_dos?
    return if reservation_player.duplicates.whitelisted.any?

    server.ssh_exec(
      %(
        sudo iptables -w #{xtables_timeout} -I #{chain_name} 1 -s #{reservation_player.ip} -j ACCEPT -m comment --comment "#{chain_name}-#{reservation_player.steam_uid}"
      ), log_stderr: true
    )
    reservation_player.update_column(:whitelisted, true)

    Rails.logger.info "Whitelisted player #{reservation_player.name} (#{reservation_player.steam_uid}) with IP #{reservation_player.ip} in the firewall for reservation #{reservation_player.reservation_id}"
  end

  private

  def xtables_timeout
    5
  end

  def chain_name
    "serveme-#{id}"
  end
end
