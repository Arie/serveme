# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LocalZipFileCreator do
  let(:reservation) { double(status_update: nil, zipfile_name: 'local-test.zip') }
  let(:source_dir) { Dir.mktmpdir }
  let(:zip_path) { Rails.root.join('tmp', 'local-test.zip') }

  after do
    FileUtils.remove_entry(source_dir)
    FileUtils.rm_f(zip_path)
  end

  it 'zips copies with IPs and API keys stripped, leaving the originals alone' do
    log = File.join(source_dir, 'l1.log')
    File.write(log, %(L 10/17/2026 - 12:00:00: "p<2><[U:1:1]><>" connected, address "1.2.3.4:27005"\nrcon: logstf_apikey "secretkey"\n))
    demo = File.join(source_dir, 'match.dem')
    File.write(demo, 'demo')

    creator = described_class.new(reservation, [ log, demo ])
    allow(creator).to receive(:zipfile_name_and_path).and_return(zip_path)
    creator.create_zip

    zipped_log = Zip::File.open(zip_path) { |zip| zip.read('l1.log') }
    expect(zipped_log).not_to include('1.2.3.4')
    expect(zipped_log).not_to include('secretkey')
    expect(Zip::File.open(zip_path) { |zip| zip.read('match.dem') }).to eq('demo')
    expect(File.read(log)).to include('secretkey')
  end
end
