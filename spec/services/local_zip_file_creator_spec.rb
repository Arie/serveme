require 'spec_helper'

describe LocalZipFileCreator do

  let!(:zipper_class)  { LocalZipFileCreator }
  let!(:reservation)   { double(:server => server, :status_update => nil) }
  let!(:server)        { double(:zip_file_creator_class => zipper_class) }

  describe '#zip' do

    it "it adds the files to zip to a zipfile" do
      zip_file = LocalZipFileCreator.new(reservation, ["foo'bar"])
      zip_file.stub(:server => server)
      zip_file.stub(:files_to_zip => ['foo/qux.zip'])
      zip_file.stub(:zipfile_name_and_path => 'bar.zip')
      zip_zip_file = double
      Zip::File.should_receive(:open).with(zip_file.zipfile_name_and_path, Zip::File::CREATE).and_yield(zip_zip_file)
      zip_zip_file.should_receive(:add).with('qux.zip', 'foo/qux.zip')
      zip_file.zip
    end

  end
end
