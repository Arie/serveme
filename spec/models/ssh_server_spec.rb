require 'spec_helper'

describe SshServer do

  describe '#remove_configuration' do

    it 'deletes the reservation configs' do
      subject.stub(:tf_dir => '/tmp/foo/tf')
      subject.should_receive(:execute).with("rm -f /tmp/foo/tf/cfg/reservation.cfg /tmp/foo/tf/cfg/ctf_turbine.cfg")
      subject.remove_configuration
    end

  end

  describe '#restart' do

    it "sends the software termination signal to the process" do
      subject.stub(:process_id => 1337)
      subject.should_receive(:execute).with("kill -15 #{subject.process_id}")
      subject.restart
    end

  end

  describe '#find_process_id' do

    it 'finds correct pid' do
      subject.stub(:port => '27015')
      subject.should_receive(:execute).with("ps ux | grep port | grep #{subject.port} | grep srcds_linux | grep -v grep | grep -v ruby | awk '{print \$2}'")
      subject.find_process_id
    end

  end

  describe '#demos' do

    it 'finds the demo files' do
      subject.stub(:shell_output_to_array)
      subject.stub(:tf_dir => "foo")
      subject.should_receive(:execute).with("ls #{subject.tf_dir}/*.dem")
      subject.demos
    end

  end

  describe '#logs' do

    it 'finds the log files' do
      subject.stub(:shell_output_to_array)
      subject.stub(:tf_dir => "foo")
      subject.should_receive(:execute).with("ls #{subject.tf_dir}/logs/*.log")
      subject.logs
    end

  end

  describe '#remove_logs_and_demos' do

    it 'removes the logs and demos' do
      subject.stub(:logs_and_demos => ['foo', 'bar'])
      subject.should_receive(:execute).with('rm -f foo bar')
      subject.remove_logs_and_demos
    end

  end

  describe '#update_configuration' do

    it 'uploads the temporary reservation file to the server' do
      output_filename = double
      output_content = double
      temp_file = double.as_null_object
      temp_file.stub(:path => "foo")
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

    it "gets the command results by calling stdout on the ssh_exec result" do
      command = 'foo'
      subject.should_receive(:ssh_exec).with(command).and_return(double(:stdout => "Great success!"))
      subject.execute(command).should == "Great success!"
    end

  end

  describe '#ssh_exec' do
    it "calls the ssh API with ip and command" do
      command = double
      ip = double
      ssh = double
      subject.stub(:ssh => ssh, :ip => ip)
      ssh.should_receive(:ssh).with(ip, command)

      subject.ssh_exec(command)
    end
  end

  describe '#ssh' do

    it "creates the Net::SSH::Simple instance" do
      subject.stub(:ip => double)
      Net::SSH::Simple.should_receive(:new).with({:host_name => subject.ip})
      subject.ssh
    end

  end

  describe '#log_copier_class' do

    it "returns the class used to copy SshServer logs" do
      subject.log_copier_class.should == RemoteLogCopier
    end

  end

  describe '#zip_file_creator_class' do

    it "returns the class used to create SshServer zipfiles" do
      subject.zip_file_creator_class.should == SshZipFileCreator
    end

  end

  describe '#copy_to_server' do

    it "uses scp to copy files to the server" do
      files = [File.join('foo')]
      destination = 'bar'
      scp = double(:scp)
      scp_upload = double(:scp_upload, :wait => true)

      Net::SCP.should_receive(:start).with(subject.ip, nil).and_yield(scp)
      scp.should_receive(:upload).with('foo', 'bar').and_return(scp_upload)
      subject.copy_to_server(files, destination)
    end
  end

  describe '#list_files' do

    it "uses the sftp instance list the files on the server" do
      subject.stub(:tf_dir => "/foo/tf")
      sftp_dir = double(:sftp_dir)
      sftp_entry = double(:sftp_entry, :name => "file_entry")
      dir = "cfg"
      sftp_dir.should_receive(:foreach).with(File.join(subject.tf_dir, dir)).and_yield(sftp_entry)
      sftp = double(:sftp, dir: sftp_dir)
      Net::SFTP.should_receive(:start).with(subject.ip, nil).and_yield(sftp)
      subject.list_files(dir).should == ["file_entry"]
    end

  end


  describe '#copy_from_server' do

    it "uses the sftp instance to copy files from the server" do
      files = [File.join('foo')]
      destination = 'bar'
      sftp = double :file
      sftp_download = double :sftp_download, wait: true

      Net::SFTP.should_receive(:start).with(subject.ip, nil).and_yield(sftp)
      sftp.should_receive(:download).with(files.first, "bar").and_return sftp_download
      subject.copy_from_server(files, destination)
    end

    it "can copy files to a destination dir" do
      files = [File.join('foo')]
      Dir.mktmpdir do |dir|
        sftp = double :file
        sftp_download = double :sftp_download, wait: true

        Net::SFTP.should_receive(:start).with(subject.ip, nil).and_yield(sftp)
        sftp.should_receive(:download).with(files.first, "bar").and_return sftp_download
        subject.copy_from_server(files, "bar")
      end
    end

  end

  describe '#upload_configuration' do

    it 'uses copy_to_server to transfer the configuration to the reservation file destination' do
      subject.should_receive(:copy_to_server).with(['foo.cfg'], 'reservation.cfg')
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

end
