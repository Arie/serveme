# frozen_string_literal: true

module Mitigations
  def chain_name
    "serveme-#{id}"
  end

  def enable_mitigations
    server.execute(
      %(
        sudo iptables -N #{chain_name} &&
        sudo iptables -A #{chain_name} -p tcp --destination-port #{server.port} -m limit --limit 100/s --limit-burst 100 -j ACCEPT &&
        sudo iptables -A #{chain_name} -p udp --destination-port #{server.port} -m limit --limit 300/s --limit-burst 600 -j ACCEPT &&
        sudo iptables -A #{chain_name} -p tcp --destination-port #{server.port} -j DROP &&
        sudo iptables -A #{chain_name} -p udp --destination-port #{server.port} -j DROP &&
        sudo iptables -A INPUT -j #{chain_name}
      )
    )
  end

  def disable_mitigations
    server.execute(
      %(
        sudo iptables -D INPUT -j #{chain_name} &&
        sudo iptables --flush #{chain_name} &&
        sudo iptables -X #{chain_name}
      )
    )
  end

  def allow_player(ip)
    server.execute(
      %(
        sudo iptables -I #{chain_name} 1 -p tcp -s #{ip} --destination-port #{server.port} -j ACCEPT &&
        sudo iptables -I #{chain_name} 1 -p udp -s #{ip} --destination-port #{server.port} -j ACCEPT
      )
    )
  end
end
