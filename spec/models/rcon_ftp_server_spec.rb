require 'spec_helper'

describe RconFtpServer do

  before do
    subject.stub(:tf_dir => '/foo/bar')
  end

  describe '#remove_configuration' do

    it 'deletes the reservation configs' do
      configuration_files = ["/foo/bar/cfg/reservation.cfg", "/foo/bar/cfg/ctf_turbine.cfg"]
      subject.should_receive(:delete_from_server).with(configuration_files)
      subject.remove_configuration
    end

  end

  describe '#restart' do

    it "sends the software termination signal to the process" do
      subject.should_receive(:rcon_exec).with("_restart")
      subject.restart
    end

  end

  describe '#demos' do

    it 'finds the demo files' do
      ftp = double
      subject.stub(:ftp => ftp)
      ftp.should_receive(:nlst).with("#{subject.tf_dir}/*.dem")
      subject.demos
    end

  end

  describe '#delete_from_server' do

    it 'sends the ftp delete command for the given files' do
      files = ['foo.log']
      ftp = double
      subject.stub(:ftp => ftp)
      ftp.should_receive(:delete).with(files.first)
      subject.delete_from_server(files)
    end

    it 'logs an error when deleting failed' do
      files = ['foo.log']
      ftp = double
      subject.stub(:ftp => ftp)
      logger = double
      Rails.stub(:logger => logger)

      ftp.should_receive(:delete).with(files.first).and_raise Net::FTPPermError
      logger.should_receive(:error).with("couldn't delete file: foo.log")
      subject.delete_from_server(files)
    end

  end

  describe '#logs' do

    it 'finds the log files' do
      ftp = double
      subject.stub(:ftp => ftp)
      ftp.should_receive(:nlst).with("#{subject.tf_dir}/logs/*.log")
      subject.logs
    end

  end

  describe "#list_files" do

    it "lists the files in a given dir" do
      dir = "cfg"
      files = ["/foo/bar/etf2l.cfg", "/foo/bar/koth.cfg"]
      ftp = double
      subject.stub(:ftp => ftp)
      ftp.should_receive(:nlst).with(File.join(subject.tf_dir, dir, "*")).and_return(files)
      subject.list_files(dir).should == ['etf2l.cfg', 'koth.cfg']
    end

  end

  describe '#remove_logs_and_demos' do

    it 'removes the logs and demos' do
      logs_and_demos = double
      subject.stub(:logs_and_demos => logs_and_demos)
      subject.should_receive(:delete_from_server).with(logs_and_demos)

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

  describe '#ftp' do

    it "creates the Net::FTP instance" do
      subject.stub(:ip => 'ip', :ftp_username => double, :ftp_password => double)
      ftp = double
      Net::FTP.should_receive(:new).with("ip:21", subject.ftp_username, subject.ftp_password).and_return(ftp)
      ftp.should_receive(:passive=).with(true)
      subject.ftp
    end

  end

  describe '#log_copier_class' do

    it "returns the class used to copy RconFtpServer logs" do
      subject.log_copier_class.should == RemoteLogCopier
    end

  end

  describe '#zip_file_creator_class' do

    it "returns the class used to create SshServer zipfiles" do
      subject.zip_file_creator_class.should == FtpZipFileCreator
    end

  end

  describe '#copy_to_server' do

    it "uses the ftp instance to copy files to the server" do
      files = [File.join('foo')]
      destination = 'bar'
      ftp = double
      destination_file = File.join(destination, 'foo')
      ftp.should_receive(:putbinaryfile).with(files.first, destination_file)
      subject.stub(:ftp => ftp)

      subject.copy_to_server(files, destination)
    end
  end

  describe '#copy_from_server' do

    it "uses the ftp instance to copy files from the server" do
      files = [File.join('foo')]
      destination = 'bar'
      ftp = double
      subject.stub(:ftp => ftp)

      ftp.should_receive(:getbinaryfile).with('foo', 'bar/foo')
      subject.copy_from_server(files, destination)
    end
  end

  describe '#upload_configuration' do

    it 'puts the file on the server with ftp' do
      ftp = double
      ftp.should_receive(:putbinaryfile).with('foo.cfg', 'reservation.cfg')
      subject.stub(:ftp => ftp)
      subject.upload_configuration('foo.cfg', 'reservation.cfg')
    end
  end

  describe '#current_reservation' do

    it 'finds a reservation that has just expired as the current reservation' do

      server      = create :server
      server.update_attribute(:type, "RconFtpServer")
      server = RconFtpServer.find(server.id)
      reservation = create :reservation, :starts_at => 10.minutes.ago, :ends_at => 1.hour.from_now, :server => server
      reservation.update_attribute(:ends_at, 1.second.ago)
      server.current_reservation.should == reservation
    end
  end

end
