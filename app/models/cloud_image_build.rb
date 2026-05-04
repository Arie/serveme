# typed: true
# frozen_string_literal: true

class CloudImageBuild < ActiveRecord::Base
  STATUSES = %w[queued running succeeded failed skipped_locked].freeze
  TERMINAL_STATUSES = %w[succeeded failed skipped_locked].freeze

  belongs_to :triggered_by_user, class_name: "User", optional: true

  validates :version, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :in_progress, -> { where(status: %w[queued running]) }

  def finished?
    TERMINAL_STATUSES.include?(status)
  end

  def duration
    return nil unless started_at && finished_at
    T.must(finished_at) - T.must(started_at)
  end

  def triggered_by_label
    triggered_by_user&.nickname || "automated"
  end

  class << self
    def broadcast_history
      Turbo::StreamsChannel.broadcast_replace_to(
        "cloud_image_builds_index",
        target: "build-history",
        partial: "admin/cloud_image_builds/history",
        locals: { builds: recent.includes(:triggered_by_user).limit(20) }
      )
    end
  end
end
