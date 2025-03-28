# typed: false
# frozen_string_literal: true

module FtpAccess
  extend T::Sig

  require "net/ftp"

  sig { returns(T::Array[String]) }
  def demos
    @demos ||= list_files("/", "*.dem").map { |file| "#{tf_dir}/#{file}" }
  end

  sig { returns(T::Array[String]) }
  def logs
    @logs ||= list_files("logs", "*.log").map { |file| "#{tf_dir}/logs/#{file}" }
  end

  sig { params(dir: String, pattern: String).returns(T::Array[String]) }
  def list_files(dir, pattern = "*")
    ftp.nlst(File.join(tf_dir, dir, pattern)).collect do |f|
      File.basename(f)
    end
  end

  sig { params(configuration_file: String, upload_file: String).returns(T.untyped) }
  def upload_configuration(configuration_file, upload_file)
    logger.debug "FTP PUT, CONFIG FILE: #{configuration_file} DESTINATION: #{upload_file}"
    ftp.putbinaryfile(configuration_file, upload_file)
  end

  sig { params(files: [ String ], destination_dir: String).returns(T.untyped) }
  def copy_to_server(files, destination_dir)
    logger.debug "FTP PUT, FILES: #{files} DESTINATION: #{destination_dir}"
    files.each do |file|
      destination_file = File.join(destination_dir, File.basename(file)).to_s
      ftp.putbinaryfile(file, destination_file)
    end
  end

  sig { params(files: [ String ], destination: String).returns(T.untyped) }
  def copy_from_server(files, destination)
    return if files.none?

    logger.debug "FTP GET, FILES: #{files} DESTINATION: #{destination}"
    threads = files.each_slice(file_count_per_thread(files)).to_a.map do |files_for_thread|
      Thread.new do
        ftp = make_ftp_connection
        files_for_thread.each do |file|
          ftp.getbinaryfile(file, File.join(destination, File.basename(file)))
        rescue StandardError => e
          Rails.logger.error "couldn't download file: #{file} - #{e}"
          Sentry.capture_exception(e) if Rails.env.production?
        end
      end
    end
    threads.map { |t| t.join(60) }
  end

  sig { params(files: [ String ]).returns(T.untyped) }
  def delete_from_server(files)
    return if files.none?

    threads = files.each_slice(file_count_per_thread(files)).to_a.map do |files_for_thread|
      Thread.new do
        ftp = make_ftp_connection
        files_for_thread.each do |file|
          ftp.send(:delete, file.shellescape)
        rescue StandardError
          Rails.logger.error "couldn't delete file: #{file.shellescape}"
        end
      end
    end
    threads.map { |t| t.join(30) }
  end

  def zip_file_creator_class
    DownloadThenZipFileCreator
  end

  def ftp
    @ftp ||= make_ftp_connection
  end

  sig { returns(T.nilable(Net::FTP)) }
  def make_ftp_connection
    ftp = Net::FTP.new
    ftp.passive = true
    ftp.connect(ip, ftp_port.presence || 21)
    ftp.login(ftp_username, ftp_password)
    ftp
  rescue EOFError
    Rails.logger.error "Got an EOF error on server #{id}: #{name}"
  end

  sig { returns(Integer) }
  def ftp_connection_pool_size
    4
  end

  sig { params(files: Array).returns(Integer) }
  def file_count_per_thread(files)
    (files.size / ftp_connection_pool_size.to_f).ceil
  end
end
