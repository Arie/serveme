# frozen_string_literal: true

require 'spec_helper'

describe MapUpload do
  include ActionDispatch::TestProcess::FixtureFile

  subject do
    file = file_fixture_upload('achievement_idle.bsp', 'application/octet-stream')
    map_upload = described_class.new
    map_upload.file = file
    map_upload
  end
  it 'requires a user' do
    subject.valid?
    subject.should have(1).error_on(:user_id)
  end

  it 'fails on a bad map file' do
    bad_map = file_fixture_upload('cfg.zip', 'application/octet-stream')
    subject.file = bad_map
    subject.valid?
    expect(subject.errors.full_messages).to include('File not a map (bsp) file')
  end
end
