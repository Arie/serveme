require 'spec_helper'

describe RconFtpServer do

  before do
    subject.stub(:game_dir => '/foo/bar')
  end

  describe '#remove_configuration' do

    it 'deletes the reservation configs' do
      configuration_files = ["/foo/bar/cfg/reservation.cfg"]
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
      ftp.should_receive(:nlst).with("#{subject.game_dir}/*.dem").and_return(["bla.dem", "foo.dem"])
      subject.demos.should eql ["#{subject.game_dir}/bla.dem", "#{subject.game_dir}/foo.dem"]
    end

  end

  describe '#delete_from_server' do

    it 'sends the ftp delete command for the given files' do
      files = ['foo.log']
      ftp = double
      subject.stub(:make_ftp_connection => ftp)
      ftp.should_receive(:delete).with(files.first)
      subject.delete_from_server(files)
    end

    it 'logs an error when deleting failed' do
      files = ['foo.log']
      ftp = double
      subject.stub(:make_ftp_connection => ftp)
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
      ftp.should_receive(:nlst).with("#{subject.game_dir}/logs/*.log").and_return(["foo", "bar"])
      subject.logs.should eql ["#{subject.game_dir}/logs/foo", "#{subject.game_dir}/logs/bar"]
    end

  end

  describe "#list_files" do

    it "lists the files in a given dir" do
      dir = "cfg"
      files = ["/foo/bar/etf2l.cfg", "/foo/bar/koth.cfg"]
      ftp = double
      subject.stub(:ftp => ftp)
      ftp.should_receive(:nlst).with(File.join(subject.game_dir, dir, "*")).and_return(files)
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
      Net::FTP.should_receive(:new).and_return(ftp)
      ftp.should_receive(:passive=).with(true)
      ftp.should_receive(:connect).with('ip', 21)
      ftp.should_receive(:login).with(subject.ftp_username, subject.ftp_password)
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
      subject.stub(:make_ftp_connection => ftp)

      subject.copy_to_server(files, destination)
    end
  end

  describe '#copy_from_server' do

    it "uses the ftp instance to copy files from the server" do
      files = [File.join('foo')]
      destination = 'bar'
      ftp = double
      subject.stub(:make_ftp_connection => ftp)

      ftp.should_receive(:getbinaryfile).with('foo', 'bar/foo')
      subject.copy_from_server(files, destination)
    end

    it 'logs an error when downloading failed' do
      files = ['foo.log']
      destination = 'bar'
      ftp = double
      subject.stub(:make_ftp_connection => ftp)
      logger = double
      Rails.stub(:logger => logger)

      ftp.should_receive(:getbinaryfile).with('foo.log', 'bar/foo.log').and_raise Net::FTPPermError
      logger.should_receive(:error).with("couldn't download file: foo.log - Net::FTPPermError")
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

  describe "#file_count_per_thread" do

    it "calculates how many files each thread should get to meet the connection limit" do
      files = 1.upto(100).to_a
      subject.file_count_per_thread(files).should eql 25
    end

  end

  describe "#make_ftp_connection " do

    it 'logs an error on EOF' do
      subject.stub(:id => 1, :name => "Server Name")
      logger = double
      Rails.stub(:logger => logger)

      Net::FTP.should_receive(:new).and_raise EOFError
      logger.should_receive(:error).with("Got an EOF error on server 1: Server Name")
      subject.make_ftp_connection
    end

  end

end
