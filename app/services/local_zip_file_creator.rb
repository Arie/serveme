# typed: true
# frozen_string_literal: true

require "open3"

class LocalZipFileCreator < ZipFileCreator
  def create_zip
    zip
    chmod
  end

  def zip
    reservation.status_update("Zipping logs and demos of locally running server")
    _, stderr, status = T.unsafe(Open3).capture3("zip", "-j", zipfile_name_and_path.to_s, *files_to_zip)
    Rails.logger.error("Failed to create zipfile: #{stderr}") unless status.success?
  end
end
