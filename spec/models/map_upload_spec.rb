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

  context "archives", :map_archive do

    it "extracts the zip when uploading a zip" do
      source = File.open(Rails.root.join("spec", "fixtures", "maps.zip"))
      zip = Tempfile.new(["foo", ".zip"])
      zip.write source.read
      zip.close

      create :map_upload, :file => zip

      maps_with_path = Dir.glob(File.join(MAPS_DIR, "*.bsp"))
      maps = maps_with_path.map { |file| File.basename(file) }
      expect(maps).to include "achievement_idle.bsp", "achievement_idle_foo.bsp"
    end

    it "extracts the bz2 when uploading a bz2" do
      source = File.open(Rails.root.join("spec", "fixtures", "achievement_idle.bsp.bz2"))
      FileUtils.cp(source, Rails.root.join("spec", "fixtures", "foo.bsp.bz2"))
      copy = File.open(Rails.root.join("spec", "fixtures", "foo.bsp.bz2"))

      create :map_upload, :file => copy

      maps_with_path = Dir.glob(File.join(MAPS_DIR, "*.bsp*"))
      maps = maps_with_path.map { |file| File.basename(file) }
      expect(maps).to include "foo.bsp", "foo.bsp.bz2"
    end

  end

  it "triggers the upload to the servers" do
    UploadFilesToServersWorker.should_receive(:perform_async)
    create :map_upload
  end

end
