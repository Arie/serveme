# frozen_string_literal: true

module Mitigations
  def enable_mitigations
    server.ssh_exec(
      %(
        #{iptables} -D PREROUTING -p udp -m udp --dport 27015 -j NOTRACK;
        #{iptables} -I PREROUTING -p udp -m udp --dport 27015 -j NOTRACK &&
        #{iptables} -D PREROUTING -t raw -p udp --destination-port #{server.port} -j #{chain_name};
        #{iptables} -D PREROUTING -t raw -p tcp --destination-port #{server.port} -j #{chain_name};
        #{iptables} -t raw --flush #{chain_name};
        #{iptables} -N #{chain_name} -t raw;
        #{iptables} -A #{chain_name} -t raw -p tcp -m limit --limit 100/s --limit-burst 100 -j ACCEPT &&
        #{allow_limited_udp_rule}
        #{iptables} -A #{chain_name} -t raw -j DROP &&
        #{iptables} -A PREROUTING -t raw -p udp --destination-port #{server.port} -j #{chain_name} &&
        #{iptables} -A PREROUTING -t raw -p tcp --destination-port #{server.port} -j #{chain_name} &&
        #{iptables} -I #{chain_name} 1 -t raw -s direct.#{SITE_HOST} -j ACCEPT -m comment --comment "#{chain_name}-system"
      ), log_stderr: false
    )
  end

  def allow_reservation_player(reservation_player)
    if reservation_player.duplicates.whitelisted.none?
      server.ssh_exec(
        %(
          #{iptables} -I #{chain_name} 1 -t raw -s #{reservation_player.ip} -j ACCEPT -m comment --comment "#{chain_name}-#{reservation_player.steam_uid}"
        ), log_stderr: true
      )
    end
    reservation_player.update_column(:whitelisted, true)
  end

  private

  def iptables
    "sudo iptables -w #{xtables_timeout}"
  end

  def xtables_timeout
    5
  end

  def chain_name
    "serveme-#{server.id}"
  end

  def allow_limited_udp_rule
    if !server.sdr?
      "#{iptables} -A #{chain_name} -t raw -p udp -m limit --limit 300/s --limit-burst 300 -j ACCEPT &&"
    else
      ""
    end
  end
end
