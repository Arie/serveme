require 'zip/zip'
require 'spec_helper'

describe ZipFileCreator do

  let!(:zipper_class)  { LocalZipFileCreator }
  let!(:server)        { stub(:zip_file_creator_class => zipper_class) }
  let!(:reservation)   { stub(:server => server) }
  let!(:files_to_zip)  { stub }

  describe '.create' do

    it "instantiates the correct ZipFileCreator based on the server and creates the zip" do
      created_zipper = stub
      created_zipper.should_receive(:create_zip)
      zipper_class.should_receive(:new).with(reservation, files_to_zip).and_return { created_zipper }
      ZipFileCreator.create(reservation, files_to_zip)
    end

  end

  describe '#chmod' do


    it 'chmods the zipfile' do
      reservation = stub(:zipfile_name => 'destination_file.zip', :server => server)
      File.should_receive(:chmod).with(0755, Rails.root.join('public', 'uploads', 'destination_file.zip'))
      LocalZipFileCreator.any_instance.stub(:zip)

      ZipFileCreator.create(reservation, files_to_zip)
    end
  end

end
