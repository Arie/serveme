# frozen_string_literal: true

module Mitigations
  def chain_name
    "serveme-#{id}"
  end

  def anti_dos?
    #[1, 3645, 4738, 35_612].include?(user_id)
    true
  end

  def enable_mitigations
    return unless anti_dos?

    server.ssh_exec(
      %(
        sudo iptables -N #{chain_name} &&
        sudo iptables -A #{chain_name} -p tcp -m limit --limit 100/s --limit-burst 100 -j ACCEPT &&
        sudo iptables -A #{chain_name} -p udp -m limit --limit 300/s --limit-burst 300 -j ACCEPT &&
        sudo iptables -A #{chain_name} -j DROP &&
        sudo iptables -A INPUT -p udp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables -A INPUT -p tcp --destination-port #{server.port} -j #{chain_name}
      )
    )
  end

  def disable_mitigations
    return unless anti_dos?

    server.ssh_exec(
      %(
        sudo iptables -D INPUT -p udp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables -D INPUT -p tcp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables --flush #{chain_name} &&
        sudo iptables -X #{chain_name}
      )
    )
  end

  def allow_reservation_player(rp)
    return unless anti_dos?
    return if rp.duplicates.whitelisted.any?

    server.ssh_exec(
      %(
        sudo iptables -I #{chain_name} 1 -s #{rp.ip} -j ACCEPT -m comment --comment "#{chain_name}-#{rp.steam_uid}"
      )
    )
    rp.update_column(:whitelisted, true)

    Rails.logger.info "Whitelisted player #{rp.name} (#{rp.steam_uid}) with IP #{rp.ip} in the firewall for reservation #{rp.reservation_id}"
  end
end
