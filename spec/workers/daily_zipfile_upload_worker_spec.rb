# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'sidekiq/testing'

RSpec.describe DailyZipfileUploadWorker, type: :worker do
  let(:worker) { described_class.new }
  let(:now) { Time.current }

  before do
    allow(Time).to receive(:current).and_return(now)
    allow(File).to receive(:exist?).and_return(true)
    allow(zip_upload_worker).to receive(:perform)
    allow(ZipUploadWorker).to receive(:new).and_return(zip_upload_worker)
  end

  let(:zip_upload_worker) { ZipUploadWorker.new }

  it 'uploads only for ended, recent, not-yet-uploaded reservations' do
    eligible = create(:reservation, ended: true)
    eligible.update_columns(starts_at: now - 1.day - 1.hour, ends_at: now - 1.day)

    too_old = create(:reservation, ended: true)
    too_old.update_columns(starts_at: now - 3.days - 1.hour, ends_at: now - 3.days)

    not_ended = create(:reservation, ended: false)
    not_ended.update_columns(starts_at: now - 1.day - 1.hour, ends_at: now - 1.day)

    already_uploaded = create(:reservation, :with_zipfile, ended: true)
    already_uploaded.update_columns(starts_at: now - 1.day - 1.hour, ends_at: now - 1.day)

    calls = []
    allow(zip_upload_worker).to receive(:perform) { |id| calls << id }
    worker.perform
    expect(calls).to eq([ eligible.id ])
  end
end
