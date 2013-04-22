require 'spec_helper'

describe LogUpload do

  describe '#upload' do

    it 'creates a LogsTF::Log file' do
      log_file         = stub
      map_name         = 'map'
      title            = 'title'
      logs_tf_api_key  = 'api_key'
      subject.stub(:log_file => log_file, :map_name => map_name, :title => title, :logs_tf_api_key => logs_tf_api_key)
      LogsTF::Log.should_receive(:new).with(log_file, map_name, title, logs_tf_api_key)
      LogsTF::Upload.should_receive(:new).and_return { as_null_object }
      subject.upload
    end

    it "sends the upload to logs.tf" do
      log = as_null_object
      upload = stub
      subject.stub(:logs_tf_api_key => 'api_key')
      LogsTF::Log.should_receive(:new).with(nil, nil, nil, 'api_key').and_return { log }
      LogsTF::Upload.should_receive(:new).with(log).and_return { upload }
      upload.should_receive(:send)
      subject.upload
    end
  end

  describe '#log_file' do

    it 'opens the file if it exists' do
      subject.stub(:file_name => 'foo.log')
      subject.should_receive(:log_file_exists?).with('foo.log').and_return { true }
      subject.should_receive(:log_file_name_and_path).and_return { 'bar' }

      File.should_receive(:open).with('bar')
      subject.log_file
    end

  end

  describe '#log_file_name_and_path' do

    it 'creates a file name with path from the reservation_id and file_name' do
      subject.stub(:reservation_id => '12345')
      subject.stub(:file_name => 'foo.log')

      subject.log_file_name_and_path.should eql Rails.root.join('server_logs', subject.reservation_id, subject.file_name)
    end

  end

  describe '#logs_tf_api_key' do

    it "returns the user's api key if it's set" do
      user        = stub(:logs_tf_api_key => '12345')
      reservation = stub(:user => user)
      subject.stub(:reservation => reservation)
      subject.logs_tf_api_key.should == '12345'
    end

    it "returns the LOGS_TF_API_KEY constant if there's no api key for the user" do
      LOGS_TF_API_KEY = '54321'
      user = stub(:logs_tf_api_key => nil)
      subject.stub(:user => user)
      subject.logs_tf_api_key.should == '54321'

      user = stub(:logs_tf_api_key => '')
      subject.logs_tf_api_key.should == '54321'
    end
  end

  describe '#log_file_exists?' do

    it 'returns true if the requested logfile is available or this reservation' do
      subject.stub(:reservation_id => 1337)
      LogUpload.should_receive(:find_log_files).with(1337).and_return { [ { :file_name => "foo.log" } ] }
      subject.log_file_exists?('foo.log').should eql true
    end
  end

  describe '.find_log_files' do

    it 'finds the log files for a reservation and puts the info in hashes' do
      reservation_id = stub
      log_matcher = Rails.root.join('spec', 'fixtures', 'logs', '*.log')
      LogUpload.should_receive(:log_matcher).with(reservation_id).and_return { log_matcher }
      subject.stub(:log_file_name_and_path => 'bar.log')
      mtime = stub
      File.should_receive(:mtime).at_least(:once).with(anything).and_return { mtime }

      found_logs = LogUpload.find_log_files(reservation_id)
      found_logs.size.should == 2
      found_logs.should_not include(
        { :file_name_and_path => Rails.root.join('spec', 'fixtures', 'logs', 'L1234567.log').to_s,
          :file_name          => "L1234567.log",
          :last_modified      => mtime,
          :size               => 16 }
      )
      found_logs.should include(
        { :file_name_and_path => Rails.root.join('spec', 'fixtures', 'logs', 'special_characters.log').to_s,
          :file_name          => "special_characters.log",
          :last_modified      => mtime,
          :size               => 121014 }
      )
    end

  end

end
