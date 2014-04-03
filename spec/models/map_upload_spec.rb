require 'spec_helper'

describe MapUpload do

  it "requires a user" do
    subject.valid?
    subject.should have(1).error_on(:user_id)
  end

  it "fails on a bad map file" do
    bad_map = Tempfile.new(['foo', '.bsp'])
    bad_map.write "foobar"
    bad_map.close
    upload = build :map_upload, :file => bad_map
    upload.valid?
    upload.errors.full_messages.should == ["File not a map (bsp) file"]
  end

  it "triggers the upload to the servers" do
    UploadFilesToServersWorker.should_receive(:perform_async)
    create :map_upload
  end

end
