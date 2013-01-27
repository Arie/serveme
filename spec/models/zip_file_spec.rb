require 'zip/zip'
require 'spec_helper'

describe ZipFile do

  describe '.create' do

    it 'adds the files to the zip' do
      files_to_zip = ['foo/bar']
      zip_file = stub
      Zip::ZipFile.should_receive(:open).and_yield(zip_file)
      ZipFile.should_receive(:chmod)

      zip_file.should_receive(:add).with('bar', 'foo/bar')

      ZipFile.create('destination_file.zip', files_to_zip)
    end

    it 'chmods the zipfile' do
      Zip::ZipFile.should_receive(:open).and_yield(stub)

      File.should_receive(:chmod).with(0755, 'destination_file.zip')

      ZipFile.create('destination_file.zip', [])
    end

  end

end
