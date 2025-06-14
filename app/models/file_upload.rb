# typed: true
# frozen_string_literal: true

class FileUpload < ActiveRecord::Base
  extend T::Sig

  belongs_to :user
  has_many :server_uploads
  has_many :servers, through: :server_uploads
  validates_presence_of :user_id
  validate :validate_file_permissions

  mount_uploader :file, FileUploader

  sig { returns(T::Array[Server]) }
  def process_file
    files = extract_zip_to_tmp_dir
    upload_files_to_servers(files)
  end

  sig { returns(String) }
  def tmp_dir
    @tmp_dir ||= Dir.mktmpdir
  end

  def file_path_for_zip
    uploader = T.cast(file, CarrierWave::Uploader::Base)
    uploader.file&.path
  end

  def extract_zip_to_tmp_dir
    return {} unless Dir.exist?(tmp_dir)

    files_with_path = {}
    Dir.glob(File.join(tmp_dir, "**", "*")).each do |path|
      next if File.directory?(path)
      next if path.match(/(__MACOSX|.DS_Store)/)

      relative_path = path.gsub("#{tmp_dir}/", "")
      target_dir = File.dirname(relative_path)
      files_with_path[target_dir] ||= []
      files_with_path[target_dir] << path
    end

    return files_with_path if files_with_path.any?

    zip_path = file_path_for_zip
    return {} unless zip_path && File.exist?(zip_path)

    Zip::File.foreach(zip_path) do |zipped_file|
      filename = File.basename(zipped_file.name)
      FileUtils.mkdir_p(File.join(tmp_dir, zipped_file.name)) if zipped_file.directory?

      next if filename.match(/(__MACOSX|.DS_Store)/) || zipped_file.directory?

      target_dir = zipped_file.name.split("/")[0..-2].join("/")
      files_with_path[target_dir] ||= []

      dest_path = File.join(tmp_dir, target_dir, filename)
      FileUtils.rm_rf(dest_path) if File.exist?(dest_path)
      zipped_file.extract(dest_path) { false }
      files_with_path[target_dir] << dest_path
    end
    files_with_path
  end

  sig { params(files: T::Hash[String, T::Array[String]]).returns(T::Array[Server]) }
  def upload_files_to_servers(files)
    Server.active.to_a.shuffle.each do |server|
      upload_files_to_server(server, files)
    end
  end

  def upload_files_to_server(server, files_with_path)
    server_upload = ServerUpload.where(file_upload_id: id, server_id: server.id).first_or_create!
    UploadFilesToServerWorker.perform_async("server_upload_id" => server_upload.id, "files_with_path" => files_with_path)
  end

  private

  def validate_file_permissions
    return if user&.admin?
    zip_path = file_path_for_zip
    return unless zip_path && File.exist?(zip_path)

    files = extract_zip_to_tmp_dir
    files.each do |path, file_paths|
      file_paths.each do |file_path|
        full_path = File.join(path, File.basename(file_path))
        unless user&.can_upload_to?(full_path)
          errors.add(:file, "contains files in unauthorized path: #{path}")
          break
        end
      end
    end
  end
end
