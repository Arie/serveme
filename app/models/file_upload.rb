# typed: true
# frozen_string_literal: true

class FileUpload < ActiveRecord::Base
  extend T::Sig

  belongs_to :user
  has_many :server_uploads
  has_many :servers, through: :server_uploads
  validates_presence_of :user_id

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

  def extract_zip_to_tmp_dir
    files_with_path = {}
    Zip::File.foreach(T.cast(file, FileUploader).file.file) do |zipped_file|
      filename = File.basename(zipped_file.name)
      Dir.mkdir(File.join(tmp_dir, zipped_file.name)) if zipped_file.directory?

      next if filename.match(/(__MACOSX|.DS_Store)/) || zipped_file.directory?

      target_dir = zipped_file.name.split('/')[0..-2].join('/')
      files_with_path[target_dir] ||= []

      zipped_file.extract(File.join(tmp_dir, target_dir, filename)) { false }
      files_with_path[target_dir] << File.join(tmp_dir, target_dir, filename)
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
    UploadFilesToServerWorker.perform_async('server_upload_id' => server_upload.id, 'files_with_path' => files_with_path)
  end
end
