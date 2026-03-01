# typed: false
# frozen_string_literal: true

namespace :mitigations do
  desc "Remove old serveme-{server_id} iptables chains, replaced by serveme-{port} chains"
  task migrate_chains: :environment do
    iptables = "sudo iptables -w 5"

    servers = Server.active.where(type: %w[SshServer CloudServer]).select(&:supports_mitigations?)
    puts "Found #{servers.size} servers with mitigations support"

    servers.each do |server|
      old_chain = "serveme-#{server.id}"
      port = server.port

      commands = %(
        #{iptables} -D PREROUTING -t raw -p udp --destination-port #{port} -j #{old_chain} 2>/dev/null;
        #{iptables} -D PREROUTING -t raw -p tcp --destination-port #{port} -j #{old_chain} 2>/dev/null;
        #{iptables} -t raw --flush #{old_chain} 2>/dev/null;
        #{iptables} -t raw -X #{old_chain} 2>/dev/null;
        echo "done"
      )

      print "  #{server.name} (id=#{server.id}, port=#{port}): removing #{old_chain}..."
      begin
        result = server.mitigation_ssh_exec(commands)
        puts " OK"
      rescue => e
        puts " FAILED: #{e.class} - #{e.message}"
      end
    end

    puts "Migration complete. New serveme-{port} chains will be created on next reservation start."
  end
end
