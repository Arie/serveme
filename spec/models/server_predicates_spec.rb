# typed: false
# frozen_string_literal: true

require 'spec_helper'

# Polymorphic type predicates replacing scattered `is_a?(<ServerSubclass>)`
# checks. Each Server subclass must answer these correctly.
# NOTE: `Server.new` STI-defaults to LocalServer (the `type` column default), so
# there is no "bare Server" instance to test. The NfoServer/RconFtpServer/
# TragicServer subclasses exercise the inherited base-class defaults instead.
describe 'Server type predicates' do
  let(:local)       { LocalServer.new }
  let(:ssh)         { SshServer.new }
  let(:cloud)       { CloudServer.new }
  let(:nfo)         { NfoServer.new }
  let(:rcon_ftp)    { RconFtpServer.new }
  let(:tragic)      { TragicServer.new }

  describe '#cloud?' do
    it 'is true only for CloudServer' do
      expect(cloud.cloud?).to be(true)
    end

    it 'is false for every non-cloud server type' do
      expect(local.cloud?).to be(false)
      expect(ssh.cloud?).to be(false)
      expect(nfo.cloud?).to be(false)
      expect(rcon_ftp.cloud?).to be(false)
      expect(tragic.cloud?).to be(false)
    end
  end

  describe '#local?' do
    it 'is true only for LocalServer' do
      expect(local.local?).to be(true)
    end

    it 'is false for every non-local server type' do
      expect(ssh.local?).to be(false)
      expect(cloud.local?).to be(false)
      expect(nfo.local?).to be(false)
      expect(rcon_ftp.local?).to be(false)
      expect(tragic.local?).to be(false)
    end
  end

  describe '#ssh_based?' do
    it 'is true for servers whose files/commands go over SSH (SshServer, CloudServer)' do
      expect(ssh.ssh_based?).to be(true)
      expect(cloud.ssh_based?).to be(true)
    end

    it 'is false for local and FTP-based server types' do
      expect(local.ssh_based?).to be(false)
      expect(nfo.ssh_based?).to be(false)
      expect(rcon_ftp.ssh_based?).to be(false)
      expect(tragic.ssh_based?).to be(false)
    end
  end

  # Call-site behaviour: ReservationCleanupWorker#zip_files dispatches purely on
  # the new predicates and must still reject FTP-based RemoteServers.
  describe 'ReservationCleanupWorker#zip_files dispatch (call site)' do
    let(:worker) { ReservationCleanupWorker.new }

    define_method(:zip_files_for) do |server|
      allow(worker).to receive(:server).and_return(server)
      worker.send(:zip_files)
    end

    it 'routes LocalServer to local zipping' do
      expect(worker).to receive(:zip_local_server_files)
      zip_files_for(LocalServer.new)
    end

    it 'routes SshServer and CloudServer to ssh zipping' do
      expect(worker).to receive(:zip_ssh_server_files).twice
      zip_files_for(SshServer.new)
      zip_files_for(CloudServer.new)
    end

    it 'raises for FTP-based RemoteServers (RconFtpServer)' do
      expect { zip_files_for(RconFtpServer.new) }.to raise_error(/Unexpected server type/)
    end
  end
end
