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

end
