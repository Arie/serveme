# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe SshServer do
  describe '#remove_configuration' do
    it 'deletes the reservation configs' do
      subject.stub(tf_dir: '/tmp/foo/tf')
      subject.should_receive(:execute).with('rm -f /tmp/foo/tf/cfg/reservation.cfg /tmp/foo/tf/cfg/ctf_turbine.cfg /tmp/foo/tf/cfg/banned_user.cfg /tmp/foo/tf/cfg/banned_ip.cfg /tmp/foo/tf/motd.txt')
      subject.remove_configuration
    end
  end

  describe '#restart' do
    it 'sends the software termination signal to the process' do
      subject.stub(process_id: 1337)
      Net::SSH.should_receive(:start).with(subject.ip, nil)
      subject.should_receive(:execute).with("kill -15 #{subject.process_id}")
      subject.restart
    end
  end

  describe '#find_process_id' do
    it 'finds correct pid for regular servers' do
      subject.stub(port: '27015')
      subject.stub(team_comtress_server?: false)
      subject.should_receive(:execute).with("ps ux | grep port | grep #{subject.port} | grep srcds_linux | grep -v grep | grep -v ruby | awk '{print $2}'")
      subject.find_process_id
    end

    it 'finds correct pid for TC2 servers' do
      subject.stub(port: '27015')
      subject.stub(team_comtress_server?: true)
      subject.should_receive(:execute).with("ps ux | grep port | grep #{subject.port} | grep tc2_linux64 | grep -v srcds_run_64 | grep -v steam-runtime-tools | grep -v grep | grep -v ruby | awk '{print $2}'")
      subject.find_process_id
    end
  end

  describe '#demos' do
    it 'finds the demo files' do
      subject.stub(:shell_output_to_array)
      subject.stub(tf_dir: 'foo')
      subject.should_receive(:execute).with("ls #{subject.tf_dir}/*.dem")
      subject.demos
    end
  end

  describe '#logs' do
    it 'finds the log files' do
      subject.stub(:shell_output_to_array)
      subject.stub(tf_dir: 'foo')
      subject.should_receive(:execute).with("ls #{subject.tf_dir}/logs/*.log")
      subject.logs
    end
  end

  describe '#remove_logs_and_demos' do
    it 'removes the logs and demos' do
      subject.stub(logs_and_demos: %w[foo bar])
      subject.should_receive(:execute).with('rm -f foo bar')
      subject.remove_logs_and_demos
    end
  end

  describe '#update_configuration' do
    it 'uploads the temporary reservation file to the server' do
      output_filename = double
      output_content = double
      temp_file = double.as_null_object
      temp_file.stub(path: 'foo')
      Tempfile.should_receive(:new).with('config_file').and_return(temp_file)
      subject.should_receive(:upload_configuration).with(temp_file.path, output_filename)
      subject.write_configuration(output_filename, output_content)
    end
  end

  describe '#execute' do
    it 'sends the command to ssh_exec' do
      command = 'foo'
      subject.should_receive(:ssh_exec).with(command).and_return(double.as_null_object)
      subject.execute(command)
    end
  end

  describe '#ssh_exec' do
    it 'calls the ssh API with ip and command' do
      command = double
      ssh = double
      subject.stub(ssh: ssh)
      ssh.should_receive(:exec!).with(command)

      subject.ssh_exec(command)
    end
  end

  describe '#execute_with_status' do
    it 'returns success status when command succeeds' do
      command = 'ls /tmp'
      wrapped_command = "#{command} && echo '__CMD_SUCCESS__' || echo '__CMD_FAILURE__'"
      ssh = double
      subject.stub(ssh: ssh)

      expect(ssh).to receive(:exec!).with(wrapped_command).and_yield(nil, :stdout, "file1\nfile2\n__CMD_SUCCESS__\n")

      result = subject.execute_with_status(command)
      expect(result[:success]).to be true
      expect(result[:stdout]).to eq("file1\nfile2")
      expect(result[:stderr]).to eq('')
    end

    it 'returns failure status when command fails' do
      command = 'ls /nonexistent'
      wrapped_command = "#{command} && echo '__CMD_SUCCESS__' || echo '__CMD_FAILURE__'"
      ssh = double
      subject.stub(ssh: ssh)

      expect(ssh).to receive(:exec!).with(wrapped_command) do |cmd, &block|
        block.call(nil, :stderr, "ls: cannot access '/nonexistent': No such file or directory")
        block.call(nil, :stdout, "__CMD_FAILURE__\n")
      end

      result = subject.execute_with_status(command)
      expect(result[:success]).to be false
      expect(result[:stderr]).to eq("ls: cannot access '/nonexistent': No such file or directory")
    end
  end

  describe '#ssh' do
    it 'creates the Net::SSH instance' do
      subject.stub(ip: double)
      Net::SSH.should_receive(:start).with(subject.ip, nil)
      subject.ssh
    end
  end

  describe '#log_copier_class' do
    it 'returns the class used to copy SshServer logs' do
      subject.log_copier_class.should == RemoteLogCopier
    end
  end

  describe '#zip_file_creator_class' do
    it 'returns the class used to create SshServer zipfiles' do
      subject.zip_file_creator_class.should == DownloadThenZipFileCreator
    end
  end

  describe '#copy_to_server' do
    it 'uses scp to copy files to the server' do
      files = [ File.join('foo') ]
      destination = 'bar'

      subject.should_receive('system').with("#{scp_command} foo #{subject.ip}:bar")
      subject.copy_to_server(files, destination)
    end
  end

  describe '#list_files' do
    it 'uses the sftp instance list the files on the server' do
      subject.stub(tf_dir: '/foo/tf')
      sftp_dir = double(:sftp_dir)
      sftp_entry = double(:sftp_entry, name: 'file_entry')
      dir = 'cfg'
      sftp_dir.should_receive(:foreach).with(File.join(subject.tf_dir, dir)).and_yield(sftp_entry)
      sftp = double(:sftp, dir: sftp_dir)
      Net::SFTP.should_receive(:start).with(subject.ip, nil).and_yield(sftp)
      subject.list_files(dir).should == [ 'file_entry' ]
    end
  end

  describe '#copy_from_server' do
    it 'uses the sftp instance to copy files from the server' do
      files = [ File.join('foo') ]
      destination = 'bar'

      subject.should_receive(:system).with("#{scp_command} #{subject.ip}:\"foo\" bar")

      subject.copy_from_server(files, destination)
    end
  end

  describe '#upload_configuration' do
    it 'uses copy_to_server to transfer the configuration to the reservation file destination' do
      subject.should_receive(:copy_to_server).with([ 'foo.cfg' ], 'reservation.cfg')
      subject.upload_configuration('foo.cfg', 'reservation.cfg')
    end
  end

  describe '#shell_output_to_array' do
    let(:shell_output) { `ls` }
    it 'takes multiple lines of shell output and turns it into an array' do
      subject.shell_output_to_array(shell_output).should have_at_least(2).items
    end

    it 'chomps off line breaks' do
      subject.shell_output_to_array(shell_output).first.should_not include("\n")
    end
  end

  describe '#move_files_to_temp_directory' do
    it 'creates temp directory on remote server and moves files' do
      reservation = double(id: 123, status_update: nil)
      temp_dir = '/tmp/foo/tf/temp_reservation_123'
      log_file = '/tmp/foo/tf/logs/log1.log'
      demo_file = '/tmp/foo/tf/demo1.dem'

      subject.stub(tf_dir: '/tmp/foo/tf')
      allow(subject).to receive(:temp_directory_for_reservation).with(reservation).and_return(temp_dir)
      allow(subject).to receive(:logs).and_return([ log_file ])
      allow(subject).to receive(:demos).and_return([ demo_file ])

      expect(subject).to receive(:execute_with_status).with("mkdir -p #{temp_dir.shellescape}").and_return({ success: true, stdout: '', stderr: '' })
      # Expect single mv command with -t flag to move all files at once
      expect(subject).to receive(:execute_with_status).with("mv -t #{temp_dir.shellescape} #{log_file.shellescape} #{demo_file.shellescape}").and_return({ success: true, stdout: '', stderr: '' })

      subject.move_files_to_temp_directory(reservation)
    end
  end

  describe '#temp_directory_for_reservation' do
    it 'returns the correct temp directory path on remote server' do
      reservation = double(id: 456)
      subject.stub(tf_dir: '/tmp/foo/tf')
      expect(subject.temp_directory_for_reservation(reservation)).to eq('/tmp/foo/tf/temp_reservation_456')
    end
  end

  define_method(:scp_command) do ||
    'scp -O -T -l 200000'
  end
end
