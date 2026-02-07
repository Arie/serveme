# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe CleanupWorker do
  let(:old_reservation)         { create :reservation, :old }
  let(:old_player_statistic)    { create :player_statistic, created_at: 40.days.ago }
  let(:old_server_statistic)    { create :server_statistic, created_at: 40.days.ago }
  let(:young_reservation)       { create :reservation, starts_at: Time.current }
  let(:young_user)              { create :user, api_key: nil, created_at: 1.day.ago }
  let(:old_user)                { create :user, api_key: nil, created_at: 8.days.ago }

  before do
    allow_any_instance_of(described_class).to receive(:remove_old_reservation_logs_and_zips)
    allow_any_instance_of(described_class).to receive(:remove_orphaned_temp_directories)
  end

  it 'finds the old reservations' do
    old_reservation
    subject.old_reservations.to_a.should == [ old_reservation ]
  end

  it 'finds the old player stats' do
    old_player_statistic
    subject.old_player_statistics.to_a.should == [ old_player_statistic ]
  end

  it 'finds the old server stats' do
    old_server_statistic
    subject.old_server_statistics.to_a.should == [ old_server_statistic ]
  end

  it 'deletes the logs and zip of old reservations and removes server/player stats' do
    old_player_statistic
    old_server_statistic
    described_class.perform_async

    expect(PlayerStatistic.count).to eql 0
    expect(ServerStatistic.count).to eql 0
  end

  it 'gives API keys to week old users' do
    young_user
    old_user
    described_class.perform_async

    expect(old_user.reload.api_key).to be_present
    expect(young_user.reload.api_key).not_to be_present
  end

  describe '#cleanup_local_orphaned_temp_directories' do
    let(:worker) { described_class.new }
    let(:old_temp_dir) { "/tmp/reservation-123" }
    let(:young_temp_dir) { "/tmp/reservation-456" }

    before do
      allow(worker).to receive(:remove_old_reservation_logs_and_zips)
      allow(Dir).to receive(:glob).with("/tmp/reservation-*").and_return([ old_temp_dir, young_temp_dir ])
    end

    it 'removes orphaned temp directories older than 24 hours' do
      old_stat = double('stat', mtime: 25.hours.ago)
      young_stat = double('stat', mtime: 1.hour.ago)

      allow(File).to receive(:directory?).and_return(false)
      allow(File).to receive(:directory?).with(old_temp_dir).and_return(true)
      allow(File).to receive(:directory?).with(young_temp_dir).and_return(true)
      allow(File).to receive(:stat).and_return(double('stat', mtime: Time.current))
      allow(File).to receive(:stat).with(old_temp_dir).and_return(old_stat)
      allow(File).to receive(:stat).with(young_temp_dir).and_return(young_stat)

      # Expect SafeFileDeletion to be called for old dir, but not young dir
      expect(SafeFileDeletion).to receive(:safe_remove_directory).with(old_temp_dir).and_return(true)
      expect(SafeFileDeletion).not_to receive(:safe_remove_directory).with(young_temp_dir)

      worker.cleanup_local_orphaned_temp_directories
    end

    it 'logs errors if cleanup fails' do
      old_stat = double('stat', mtime: 25.hours.ago)
      allow(File).to receive(:directory?).and_return(false)
      allow(File).to receive(:directory?).with(old_temp_dir).and_return(true)
      allow(File).to receive(:stat).and_return(double('stat', mtime: Time.current))
      allow(File).to receive(:stat).with(old_temp_dir).and_return(old_stat)
      allow(SafeFileDeletion).to receive(:safe_remove_directory).with(old_temp_dir).and_raise(StandardError.new("Permission denied"))

      expect(Rails.logger).to receive(:error).with(/Error removing orphaned local temp directory/)

      worker.cleanup_local_orphaned_temp_directories
    end

    it 'logs the count of cleaned directories' do
      old_stat = double('stat', mtime: 25.hours.ago)
      allow(File).to receive(:directory?).and_return(false)
      allow(File).to receive(:directory?).with(old_temp_dir).and_return(true)
      allow(File).to receive(:directory?).with(young_temp_dir).and_return(false)
      allow(File).to receive(:stat).and_return(double('stat', mtime: Time.current))
      allow(File).to receive(:stat).with(old_temp_dir).and_return(old_stat)
      allow(SafeFileDeletion).to receive(:safe_remove_directory).with(old_temp_dir).and_return(true)

      # CleanupWorker logs after successful deletion
      expect(Rails.logger).to receive(:info).with("CleanupWorker: Removed orphaned local temp directory: #{old_temp_dir}")
      expect(Rails.logger).to receive(:info).with("CleanupWorker: Cleaned up 1 orphaned local temp directories")

      worker.cleanup_local_orphaned_temp_directories
    end
  end

  describe '#cleanup_ssh_orphaned_temp_directories' do
    let(:worker) { described_class.new }
    let(:ssh_server) do
      server = SshServer.new(
        name: 'SSH TF2 Server',
        ip: '192.168.1.100',
        port: '27015',
        rcon: 'secret',
        path: '/home/tf2server/server'
      )
      server.stub(id: 1, tf_dir: tf_dir)
      server
    end
    let(:tf_dir) { "/home/tf2/tf" }

    before do
      allow(worker).to receive(:remove_old_reservation_logs_and_zips)
      allow(SshServer).to receive_message_chain(:active, :find_each).and_yield(ssh_server)
    end

    it 'removes orphaned remote temp directories older than 24 hours' do
      old_dirs = "/home/tf2/tf/temp_reservation_123\n/home/tf2/tf/temp_reservation_456"
      allow(ssh_server).to receive(:execute).with(/find/).and_return(old_dirs)

      expect(ssh_server).to receive(:execute).with("rm -rf /home/tf2/tf/temp_reservation_123")
      expect(ssh_server).to receive(:execute).with("rm -rf /home/tf2/tf/temp_reservation_456")

      worker.cleanup_ssh_orphaned_temp_directories
    end

    it 'handles errors when listing directories' do
      allow(ssh_server).to receive(:execute).with(/find/).and_raise(StandardError.new("Connection failed"))

      expect(Rails.logger).to receive(:error).with(/Error listing orphaned temp directories/)

      worker.cleanup_ssh_orphaned_temp_directories
    end

    it 'handles errors when removing individual directories' do
      old_dirs = "/home/tf2/tf/temp_reservation_123"
      allow(ssh_server).to receive(:execute).with(/find/).and_return(old_dirs)
      allow(ssh_server).to receive(:execute).with(/rm -rf/).and_raise(StandardError.new("Permission denied"))

      expect(Rails.logger).to receive(:error).with(/Error removing orphaned remote temp directory/)

      worker.cleanup_ssh_orphaned_temp_directories
    end

    it 'logs the count of cleaned directories per server' do
      old_dirs = "/home/tf2/tf/temp_reservation_123\n/home/tf2/tf/temp_reservation_456"
      allow(ssh_server).to receive(:execute).with(/find/).and_return(old_dirs)
      allow(ssh_server).to receive(:execute).with(/rm -rf/)

      expect(Rails.logger).to receive(:info).with(/Removed orphaned remote temp directory/).twice
      expect(Rails.logger).to receive(:info).with(/Cleaned up 2 orphaned remote temp directories/)

      worker.cleanup_ssh_orphaned_temp_directories
    end
  end
end
