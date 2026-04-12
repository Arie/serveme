# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LocalZipFileCreator do
  let(:zipper_class)  { LocalZipFileCreator }
  let(:reservation)   { double(server: server, status_update: nil) }
  let(:server)        { double(zip_file_creator_class: zipper_class) }

  describe '#zip' do
    it 'it adds the files to zip to a zipfile' do
      zip_creator = LocalZipFileCreator.new(reservation, [ "foo'bar" ])
      zip_creator.stub(server: server)
      zip_creator.stub(files_to_zip: [ 'foo/qux.dem' ])
      zip_creator.stub(zipfile_name_and_path: 'bar.zip')

      expect(Open3).to receive(:capture3).with('zip', '-j', 'bar.zip', 'foo/qux.dem').and_return([ "", "", double(success?: true) ])

      zip_creator.zip
    end
  end
end
