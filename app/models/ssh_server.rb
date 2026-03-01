# typed: true
# frozen_string_literal: true

class SshServer < RemoteServer
  extend T::Sig
  include SshExecution

  sig { returns(T.nilable(Net::SSH::Connection::Session)) }
  def ssh
    @ssh ||= Net::SSH.start(ip, nil)
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
    "scp -O -T -l 200000"
  end

  sig { returns(T.nilable(String)) }
  def scp_target
    ip
  end

  def sftp_start(&block)
    Net::SFTP.start(ip, nil, &block)
  end
end
