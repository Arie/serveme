require 'spec_helper'

describe ZipFileCreator do

  let!(:zipper_class)  { LocalZipFileCreator }
  let!(:server)        { double(:zip_file_creator_class => zipper_class) }
  let!(:reservation)   { double(:server => server) }
  let!(:files_to_zip)  { double }

  describe '.create' do

    it "instantiates the correct ZipFileCreator based on the server and creates the zip" do
      created_zipper = double
      created_zipper.should_receive(:create_zip)
      zipper_class.should_receive(:new).with(reservation, files_to_zip).and_return { created_zipper }
      ZipFileCreator.create(reservation, files_to_zip)
    end

  end

  describe '#chmod' do


    it 'chmods the zipfile' do
      reservation = double(:zipfile_name => 'destination_file.zip', :server => server)
      File.should_receive(:chmod).with(0755, Rails.root.join('public', 'uploads', 'destination_file.zip'))
      LocalZipFileCreator.any_instance.stub(:zip)

      ZipFileCreator.create(reservation, files_to_zip)
    end

  end


end
