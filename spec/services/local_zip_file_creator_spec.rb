require 'spec_helper'

describe LocalZipFileCreator do

  let!(:zipper_class)  { LocalZipFileCreator }
  let!(:reservation)   { double(:server => server, :status_update => nil) }
  let!(:server)        { double(:zip_file_creator_class => zipper_class) }

  describe '#zip' do

    it "it adds the files to zip to a zipfile" do
      zip_creator = LocalZipFileCreator.new(reservation, ["foo'bar"])
      zip_creator.stub(:server => server)
      zip_creator.stub(:files_to_zip => ['foo/qux.dem'])
      zip_creator.stub(:zipfile_name_and_path => 'bar.zip')

      zip_creator.should_receive(:system).with("zip -j bar.zip foo/qux.dem")

      zip_creator.zip
    end

  end
end
