# typed: true
# frozen_string_literal: true

module Reservations
  class DockerHostCapacityValidator < ActiveModel::Validator
    def validate(record)
      return unless record.server&.cloud_provider == "remote_docker"

      docker_host = DockerHost.find_by(id: record.server.cloud_location)
      return unless docker_host

      if docker_host.full_during?(record.starts_at, record.ends_at)
        record.errors.add(:server, "this location is at full capacity for the selected time, please try another")
      end
    end
  end
end
