# typed: true
# frozen_string_literal: true

class SshServer < RemoteServer
  extend T::Sig
  include SshExecution

  # `bind_address: "0.0.0.0"` forces IPv4 — some hosts publish AAAA records
  # whose routes don't actually work, raising Errno::ENETUNREACH otherwise.
  # Same reason `scp_command` below uses `-4`. Mirror this on every Net::SSH
  # / Net::SFTP / scp call we add against remote hosts.
  sig { returns(T.nilable(Net::SSH::Connection::Session)) }
  def ssh
    @ssh ||= Net::SSH.start(ip, nil, timeout: 5, keepalive: true, keepalive_interval: 5, keepalive_maxcount: 2, bind_address: "0.0.0.0")
  end

  sig { returns(T::Boolean) }
  def supports_mitigations?
    true
  end

  sig { params(command: String, log_stderr: T::Boolean).returns(String) }
  def mitigation_ssh_exec(command, log_stderr: false)
    ssh_exec(command, log_stderr: log_stderr)
  end

  private

  sig { returns(String) }
  def scp_command
    "scp -4 -O -T -l 200000 -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2"
  end

  sig { returns(T.nilable(String)) }
  def scp_target
    ip
  end

  def sftp_start(&block)
    Net::SFTP.start(ip, nil, timeout: 5, bind_address: "0.0.0.0", &block)
  end
end
