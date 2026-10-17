# typed: true
# frozen_string_literal: true

# Copies the files instead of downloading them, then strips IPs and API keys
# and zips like any other server: the zip ends up in public/uploads.
class LocalZipFileCreator < DownloadThenZipFileCreator
  extend T::Sig

  sig { params(tmp_dir: String).void }
  def fetch_files(tmp_dir)
    reservation.status_update("Zipping logs and demos of locally running server")
    FileUtils.cp(files_to_zip, tmp_dir)
  end
end
