require 'spec_helper'

describe SshServer do

  describe '#remove_configuration' do

    it 'deletes the reservation.cfg' do
      subject.stub(:reservation_config_file => '/tmp/foo')
      subject.should_receive(:execute).with("rm -f /tmp/foo")
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
      subject.should_receive(:execute).with("ls #{subject.tf_dir}/logs/L*.log")
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
      temporary_reservation_file = Rails.root.join("tmp", "temp_reservation.cfg")
      subject.stub(:id => 'foo')
      subject.stub(:temporary_reservation_config_file => temporary_reservation_file)
      subject.should_receive(:upload_configuration).with(temporary_reservation_file)
      filename = stub
      content = stub
      file = stub
      File.should_receive(:open).and_yield(file)
      file.should_receive(:write).with(content)
      subject.write_configuration(filename, content)
    end

  end

  describe '#execute' do

    it 'sends the command to ssh_exec' do
      command = 'foo'
      subject.should_receive(:ssh_exec).with(command).and_return { stub.as_null_object }
      subject.execute(command)
    end

    it "gets the command results by calling stdout on the ssh_exec result" do
      command = 'foo'
      subject.should_receive(:ssh_exec).with(command).and_return { stub(:stdout => "Great success!") }
      subject.execute(command).should == "Great success!"
    end

  end

  describe '#ssh_exec' do
    it "calls the ssh API with ip and command" do
      command = stub
      ip = stub
      ssh = stub
      subject.stub(:ssh => ssh, :ip => ip)
      ssh.should_receive(:ssh).with(ip, command)

      subject.ssh_exec(command)
    end
  end

  describe '#ssh' do

    it "creates the Net::SSH::Simple instance" do
      subject.stub(:ip => stub)
      Net::SSH::Simple.should_receive(:new).with({:host_name => subject.ip})
      subject.ssh
    end

  end

  describe '#log_copier_class' do

    it "returns the class used to copy SshServer logs" do
      subject.log_copier_class.should == SshLogCopier 
    end

  end

  describe '#zip_file_creator_class' do

    it "returns the class used to create SshServer zipfiles" do
      subject.zip_file_creator_class.should == SshZipFileCreator
    end

  end

  describe '#copy_to_server' do

    it "uses the ssh instance to copy files to the server" do
      files = [File.join('foo')]
      destination = 'bar'
      ssh = stub
      subject.stub(:ssh => ssh)

      ssh.should_receive(:scp_put).with(subject.ip, 'foo', 'bar')
      subject.copy_to_server(files, destination)
    end
  end

  describe '#copy_from_server' do

    it "uses the ssh instance to copy files from the server" do
      files = [File.join('foo')]
      destination = 'bar'
      ssh = stub
      subject.stub(:ssh => ssh)

      ssh.should_receive(:scp_get).with(subject.ip, 'foo', 'bar')
      subject.copy_from_server(files, destination)
    end
  end

  describe '#upload_configuration' do

    it 'uses copy_to_server to transfer the configuration to the reservation file destination' do
      subject.stub(:reservation_config_file => 'destination')
      configuration_file_name = stub

      subject.should_receive(:copy_to_server).with([configuration_file_name], 'destination')
      subject.upload_configuration(configuration_file_name)
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

  describe '#temporary_reservation_config_file' do

    it 'returns a temporary place to put the reservation config before uploading' do
      subject.stub(:id => 'foo')
      subject.temporary_reservation_config_file.should == Rails.root.join("tmp", "server_#{subject.id}_reservation.cfg")
    end

  end

end
