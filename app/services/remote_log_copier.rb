# typed: true
# frozen_string_literal: true

class RemoteLogCopier < LogCopier
  def copy_logs
    zipfile_name_and_path = Rails.root.join("public", "uploads", reservation.zipfile_name)
    return unless File.exist?(zipfile_name_and_path)

    Zip::File.open(zipfile_name_and_path) do |zip|
      zip.each do |entry|
        next unless entry.name.end_with?(".log")

        dest = File.join(directory_to_copy_to, File.basename(entry.name))
        File.binwrite(dest, entry.get_input_stream.read)
      end
    end
  end
end
