# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ReservationCleanupWorker do
  let(:reservation) { create(:reservation) }
  let(:temp_directory_path) { "/tmp/reservation-#{reservation.id}" }
  let(:worker) { described_class.new }

  describe '#perform' do
    context 'with a LocalServer' do
      it 'zips files, strips IPs, copies logs, scans logs, and cleans up temp directory' do
        # Setup mock files in temp directory
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with(File.join(temp_directory_path, "*")).and_return([
          "#{temp_directory_path}/log1.log",
          "#{temp_directory_path}/demo1.dem"
        ])

        # Allow all system calls (for both IP stripping and zipping)
        allow_any_instance_of(ReservationCleanupWorker).to receive(:system).and_return(true)

        # Allow File.exist? checks (for both zipfile and temp directory)
        allow(File).to receive(:exist?).and_call_original
        allow(FileUtils).to receive(:rm_f)

        # Expect status update
        expect_any_instance_of(Reservation).to receive(:status_update).with("Zipping logs and demos of locally running server")

        # Expect file chmod after zipping
        expect(File).to receive(:chmod).with(0o755, anything)

        # Expect log copy
        expect(LogCopier).to receive(:copy).with(instance_of(Reservation), instance_of(LocalServer))

        # Expect LogScanWorker to be queued after logs are copied
        expect(LogScanWorker).to receive(:perform_async).with(reservation.id)

        # Expect temp directory cleanup using safe deletion
        expect(SafeFileDeletion).to receive(:safe_remove_directory).with(temp_directory_path).and_return(true)

        worker.perform(reservation.id, temp_directory_path)
      end

      it 'skips zipping when temp directory is empty but still scans logs' do
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with(File.join(temp_directory_path, "*")).and_return([])

        expect_any_instance_of(ReservationCleanupWorker).not_to receive(:system)
        expect(LogCopier).to receive(:copy).with(instance_of(Reservation), instance_of(LocalServer))

        # LogScanWorker should still be called even if no files to zip
        expect(LogScanWorker).to receive(:perform_async).with(reservation.id)

        # Expect safe deletion to be called
        expect(SafeFileDeletion).to receive(:safe_remove_directory).with(temp_directory_path).and_return(false)

        worker.perform(reservation.id, temp_directory_path)
      end
    end

    context 'with an SshServer' do
      let!(:location) { Location.first_or_create!(name: 'Test Location') }
      let!(:ssh_server) do
        SshServer.create!(
          name: 'SSH TF2 Server',
          ip: '192.168.1.100',
          port: '27015',
          rcon: 'secret',
          path: '/home/tf2server/server',
          location: location
        )
      end
      let(:reservation) { create(:reservation, server: ssh_server) }
      let(:remote_temp_path) { "/home/tf2server/server/tf/temp_reservation_#{reservation.id}" }

      before do
        # Stub the basic server lookups
        allow(Reservation).to receive(:includes).and_return(Reservation)
        allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)

        # Mock SSH connection to prevent actual network calls
        ssh_mock = double('ssh')
        allow(ssh_mock).to receive(:exec!)
        allow(ssh_mock).to receive(:close)
        allow(Net::SSH).to receive(:start).and_return(ssh_mock)
        allow(ssh_server).to receive(:ssh).and_return(ssh_mock)
      end

      it 'downloads files, strips IPs, zips, and cleans up remote temp directory' do
        # Setup remote file listing
        remote_files = [
          "#{remote_temp_path}/match.log",
          "#{remote_temp_path}/demo.dem"
        ]
        allow(ssh_server).to receive(:execute)
          .with("ls #{remote_temp_path.shellescape}/*.* 2>/dev/null || true")
          .and_return("#{remote_temp_path}/match.log\n#{remote_temp_path}/demo.dem")

        # Expect status updates
        expect(reservation).to receive(:status_update).with("Downloading logs and demos from server")
        expect(reservation).to receive(:status_update).with("Finished downloading logs and demos from server")
        expect(reservation).to receive(:status_update).with("Zipping logs and demos")
        expect(reservation).to receive(:status_update).with("Finished zipping logs and demos")

        # Mock local temp directory creation and cleanup
        local_tmp_dir = "/tmp/temp_dir_12345"
        allow(Dir).to receive(:mktmpdir).and_return(local_tmp_dir)
        allow(FileUtils).to receive(:remove_entry).with(local_tmp_dir)

        # Expect file download from server
        expect(ssh_server).to receive(:copy_from_server).with(remote_files, local_tmp_dir)

        # Expect IP stripping in log files
        expect_any_instance_of(ReservationCleanupWorker).to receive(:system)
          .with(/sed.*#{local_tmp_dir}\/\*\.log/)
          .and_return(true)

        # Expect zip file creation
        zipfile = double('zipfile')
        allow(zipfile).to receive(:add).twice
        expect(Zip::File).to receive(:open).and_yield(zipfile)

        # Mock Dir.glob for finding downloaded files to zip
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with(File.join(local_tmp_dir, "*")).and_return([
          "#{local_tmp_dir}/match.log",
          "#{local_tmp_dir}/demo.dem"
        ])

        # Expect file permissions change
        zipfile_path = Rails.root.join("public", "uploads", reservation.zipfile_name).to_s
        expect(File).to receive(:chmod).with(0o755, zipfile_path)

        # Expect log copy
        expect(LogCopier).to receive(:copy).with(reservation, ssh_server)

        # Expect LogScanWorker to be queued after logs are copied
        expect(LogScanWorker).to receive(:perform_async).with(reservation.id)

        # Expect remote temp directory cleanup
        expect(ssh_server).to receive(:execute).with("rm -rf #{remote_temp_path.shellescape}")

        worker.perform(reservation.id, remote_temp_path)
      end

      it 'skips zipping when remote temp directory is empty' do
        # Return empty list from remote directory
        allow(ssh_server).to receive(:execute)
          .with("ls #{remote_temp_path.shellescape}/*.* 2>/dev/null || true")
          .and_return("")

        expect(reservation).to receive(:status_update).with("Downloading logs and demos from server")

        # Should not attempt to download or zip
        expect(ssh_server).not_to receive(:copy_from_server)
        expect(Zip::File).not_to receive(:open)

        # Still expect log copy, log scan, and cleanup
        expect(LogCopier).to receive(:copy).with(reservation, ssh_server)
        expect(LogScanWorker).to receive(:perform_async).with(reservation.id)
        expect(ssh_server).to receive(:execute).with("rm -rf #{remote_temp_path.shellescape}")

        worker.perform(reservation.id, remote_temp_path)
      end

      it 'handles errors when remote file listing fails' do
        # Simulate error in file listing
        allow(ssh_server).to receive(:execute)
          .with("ls #{remote_temp_path.shellescape}/*.* 2>/dev/null || true")
          .and_raise(StandardError.new("Connection timeout"))

        expect(reservation).to receive(:status_update).with("Downloading logs and demos from server")

        # Should log error and return empty list
        expect(Rails.logger).to receive(:error).with(/Error listing files in temp directory/)

        # Should not attempt to download or zip
        expect(ssh_server).not_to receive(:copy_from_server)
        expect(Zip::File).not_to receive(:open)

        # Still expect log copy, log scan, and cleanup
        expect(LogCopier).to receive(:copy).with(reservation, ssh_server)
        expect(LogScanWorker).to receive(:perform_async).with(reservation.id)
        expect(ssh_server).to receive(:execute).with("rm -rf #{remote_temp_path.shellescape}")

        worker.perform(reservation.id, remote_temp_path)
      end

      it 'handles errors when file download fails' do
        remote_files = [ "#{remote_temp_path}/match.log" ]
        allow(ssh_server).to receive(:execute)
          .with("ls #{remote_temp_path.shellescape}/*.* 2>/dev/null || true")
          .and_return("#{remote_temp_path}/match.log")

        expect(reservation).to receive(:status_update).with("Downloading logs and demos from server")

        # Mock local temp directory
        local_tmp_dir = "/tmp/temp_dir_12345"
        allow(Dir).to receive(:mktmpdir).and_return(local_tmp_dir)
        allow(FileUtils).to receive(:remove_entry).with(local_tmp_dir)

        # Simulate download failure
        expect(ssh_server).to receive(:copy_from_server)
          .with(remote_files, local_tmp_dir)
          .and_raise(StandardError.new("SCP failed"))

        # Should log error and raise
        expect(Rails.logger).to receive(:error).with(/Error processing reservation/)

        # Should still clean up local temp directory
        expect(FileUtils).to receive(:remove_entry).with(local_tmp_dir)

        expect { worker.perform(reservation.id, remote_temp_path) }.to raise_error(StandardError, "SCP failed")
      end

      it 'handles errors during remote temp directory cleanup' do
        # Setup successful zip operation
        allow(ssh_server).to receive(:execute)
          .with("ls #{remote_temp_path.shellescape}/*.* 2>/dev/null || true")
          .and_return("")

        expect(reservation).to receive(:status_update).with("Downloading logs and demos from server")
        expect(LogCopier).to receive(:copy).with(reservation, ssh_server)
        expect(LogScanWorker).to receive(:perform_async).with(reservation.id)

        # Simulate error during cleanup
        expect(ssh_server).to receive(:execute)
          .with("rm -rf #{remote_temp_path.shellescape}")
          .and_raise(StandardError.new("Permission denied"))

        # Should log error but not raise (cleanup is best-effort)
        expect(Rails.logger).to receive(:error).with(/Error removing temp directory/)

        worker.perform(reservation.id, remote_temp_path)
      end

      it 'cleans up local temp directory even when zipping fails' do
        remote_files = [ "#{remote_temp_path}/match.log" ]
        allow(ssh_server).to receive(:execute)
          .with("ls #{remote_temp_path.shellescape}/*.* 2>/dev/null || true")
          .and_return("#{remote_temp_path}/match.log")

        expect(reservation).to receive(:status_update).with("Downloading logs and demos from server")
        expect(reservation).to receive(:status_update).with("Finished downloading logs and demos from server")
        expect(reservation).to receive(:status_update).with("Zipping logs and demos")

        local_tmp_dir = "/tmp/temp_dir_12345"
        allow(Dir).to receive(:mktmpdir).and_return(local_tmp_dir)
        allow(ssh_server).to receive(:copy_from_server)
        allow_any_instance_of(ReservationCleanupWorker).to receive(:system).and_return(true)

        # Mock Dir.glob for finding files
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with(File.join(local_tmp_dir, "*")).and_return([ "#{local_tmp_dir}/match.log" ])

        # Simulate zip failure
        expect(Zip::File).to receive(:open).and_raise(StandardError.new("Disk full"))

        # Should still clean up local temp directory
        expect(FileUtils).to receive(:remove_entry).with(local_tmp_dir)
        expect(Rails.logger).to receive(:error).with(/Error processing reservation/)

        expect { worker.perform(reservation.id, remote_temp_path) }.to raise_error(StandardError, "Disk full")
      end
    end

    it 'returns early when server is nil' do
      # Stub the finder to return a reservation without a server
      reservation_with_nil_server = double(:reservation, id: 999, server: nil)
      allow(Reservation).to receive(:includes).and_return(Reservation)
      allow(Reservation).to receive(:find).with(999).and_return(reservation_with_nil_server)

      expect(Rails.logger).not_to receive(:error)

      # Should not raise when server is nil, just return early
      expect { worker.perform(999, temp_directory_path) }.not_to raise_error
    end

    it 'logs and raises errors when processing fails' do
      # Stub the worker's instance variables to trigger an error
      allow(Reservation).to receive(:includes).and_return(Reservation)
      allow(Reservation).to receive(:find).with(reservation.id).and_return(reservation)
      allow(reservation).to receive(:server).and_return(reservation.server)
      allow(reservation.server).to receive(:is_a?).and_raise(StandardError.new("Test error"))

      expect(Rails.logger).to receive(:error).with(/ReservationCleanupWorker: Error processing reservation/)

      expect { worker.perform(reservation.id, temp_directory_path) }.to raise_error(StandardError, "Test error")
    end
  end
end
