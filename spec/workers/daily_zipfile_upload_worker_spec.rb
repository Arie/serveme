# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'sidekiq/testing'

RSpec.describe DailyZipfileUploadWorker, type: :worker do
  let(:worker) { described_class.new }
  let(:now) { Time.current }
  let(:two_days_ago) { now - 2.days }

  let!(:eligible) do
    r = create(:reservation, ended: true)
    r.update_columns(starts_at: now - 1.day - 1.hour, ends_at: now - 1.day)
    r
  end
  let!(:too_old) do
    r = create(:reservation, ended: true)
    r.update_columns(starts_at: now - 3.days - 1.hour, ends_at: now - 3.days)
    r
  end
  let!(:not_ended) do
    r = create(:reservation, ended: false)
    r.update_columns(starts_at: now - 1.day - 1.hour, ends_at: now - 1.day)
    r
  end
  let!(:already_uploaded) do
    r = create(:reservation, :with_zipfile, ended: true)
    r.update_columns(starts_at: now - 1.day - 1.hour, ends_at: now - 1.day)
    r
  end

  before do
    allow(Time).to receive(:current).and_return(now)
    allow(File).to receive(:exist?).and_return(true)
    allow_any_instance_of(ZipUploadWorker).to receive(:perform)
  end

  it 'uploads only for ended, recent, not-yet-uploaded reservations' do
    calls = []
    allow_any_instance_of(ZipUploadWorker).to receive(:perform) { |_, id| calls << id }
    worker.perform
    expect(calls).to eq([ eligible.id ])
  end
end
