# typed: true
# frozen_string_literal: true

class UploadFilesToServersWorker
  include Sidekiq::Worker

  def perform(options)
    files = options['files']
    destination = options['destination']
    overwrite = options.fetch('overwrite', true)

    self.class.servers.each do |s|
      if overwrite == false
        files_already_present = s.list_files(destination)
        files_to_copy = files.reject do |f|
          files_already_present.include?(File.basename(f))
        end
      else
        files_to_copy = files
      end
      Rails.logger.info "Copying to server #{s.name}: #{files_to_copy.join(', ')}"
      s.copy_to_server(files_to_copy, File.join(s.tf_dir, destination)) if files_to_copy.any?
    end
  end

  def self.servers
    Server.active
  end
end
