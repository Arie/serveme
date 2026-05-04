# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudImageBuild do
  describe "validations" do
    it "requires version" do
      build = described_class.new(version: nil)
      expect(build).not_to be_valid
      expect(build.errors[:version]).to include("can't be blank")
    end

    it "requires status" do
      build = described_class.new(version: "1234", status: nil)
      expect(build).not_to be_valid
    end

    it "rejects unknown status values" do
      build = described_class.new(version: "1234", status: "weird")
      expect(build).not_to be_valid
      expect(build.errors[:status]).to be_present
    end

    it "is valid with required defaults" do
      build = described_class.new(version: "1234")
      expect(build).to be_valid
    end
  end

  describe "scopes" do
    it ".recent orders by created_at desc" do
      older = described_class.create!(version: "1", created_at: 2.hours.ago)
      newer = described_class.create!(version: "2", created_at: 1.hour.ago)
      expect(described_class.recent.to_a).to eq([ newer, older ])
    end

    it ".in_progress returns queued and running builds" do
      queued    = described_class.create!(version: "1", status: "queued")
      running   = described_class.create!(version: "2", status: "running")
      succeeded = described_class.create!(version: "3", status: "succeeded")
      expect(described_class.in_progress).to contain_exactly(queued, running)
      expect(described_class.in_progress).not_to include(succeeded)
    end
  end

  describe "#finished?" do
    it "returns true for terminal statuses" do
      %w[succeeded failed skipped_locked].each do |status|
        expect(described_class.new(status: status).finished?).to eq(true)
      end
    end

    it "returns false for non-terminal statuses" do
      %w[queued running].each do |status|
        expect(described_class.new(status: status).finished?).to eq(false)
      end
    end
  end

  describe "#duration" do
    it "returns nil if not finished" do
      expect(described_class.new(started_at: 1.minute.ago, finished_at: nil).duration).to be_nil
    end

    it "returns finished_at minus started_at" do
      build = described_class.new(started_at: 5.minutes.ago, finished_at: 1.minute.ago)
      expect(build.duration).to be_within(0.1).of(4.minutes)
    end
  end

  describe "#triggered_by_label" do
    it "returns user nickname when triggered by a user" do
      user = create(:user, nickname: "alice")
      build = described_class.new(triggered_by_user: user)
      expect(build.triggered_by_label).to eq("alice")
    end

    it "returns 'automated' when not triggered by a user" do
      build = described_class.new(triggered_by_user: nil)
      expect(build.triggered_by_label).to eq("automated")
    end
  end
end
