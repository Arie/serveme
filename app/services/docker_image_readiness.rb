# typed: true
# frozen_string_literal: true

# Single source of truth for "do we have a RemoteDocker image for the current
# TF2 version?". Reads the version recorded in SiteSetting (set by
# CloudImageBuildWorker, the cross-region notification, and DockerImagePollWorker)
# and compares it against the latest TF2 version reported by Steam.
#
# Fail-open by design: if either side is unknown, the image is treated as
# current so launches are never blocked on missing data.
class DockerImageReadiness
  VERSION_SETTING_KEY = "docker_image_version"

  # The TF2 version the most recent RemoteDocker image was built for, or nil
  # if nothing has been recorded yet.
  def self.recorded_version
    value = SiteSetting.get(VERSION_SETTING_KEY)
    value.present? ? value.to_i : nil
  end

  # True when we know the current TF2 version AND know our image version AND
  # the image is behind. Fail-open: false whenever either side is unknown.
  def self.stale?
    latest = Server.latest_version
    recorded = recorded_version
    return false if latest.nil? || recorded.nil?

    recorded < latest
  end
end
