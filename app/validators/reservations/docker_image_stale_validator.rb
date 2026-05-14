# typed: true
# frozen_string_literal: true

module Reservations
  # Blocks new RemoteDocker reservations while the TF2 server image is behind
  # the current TF2 version. Covers every reservation entry point (web form,
  # API, cloud reservations form) since it runs on the Reservation model.
  class DockerImageStaleValidator < ActiveModel::Validator
    def validate(record)
      return unless record.server&.cloud_provider == "remote_docker"
      return unless DockerImageReadiness.stale?

      record.errors.add(:server, "is temporarily unavailable while the TF2 server image updates, please try again in a few minutes")
    end
  end
end
