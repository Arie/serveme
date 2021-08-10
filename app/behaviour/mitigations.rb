# frozen_string_literal: true

module Mitigations
  def chain_name
    "serveme-#{id}"
  end

  def enable_mitigations
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
    server.ssh_exec(
      %(
        sudo iptables -D INPUT -p udp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables -D INPUT -p tcp --destination-port #{server.port} -j #{chain_name} &&
        sudo iptables --flush #{chain_name} &&
        sudo iptables -X #{chain_name}
      )
    )
  end

  def allow_player(ip)
    server.ssh_exec(
      %(
        sudo iptables -I #{chain_name} 1 -s #{ip} -j ACCEPT
      )
    )
  end
end
