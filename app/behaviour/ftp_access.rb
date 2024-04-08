# frozen_string_literal: true

module FtpAccess
  require 'net/ftp'

  def demos
    @demos ||= list_files('/', '*.dem').map { |file| "#{tf_dir}/#{file}" }
  end

  def logs
    @logs ||= list_files('logs', '*.log').map { |file| "#{tf_dir}/logs/#{file}" }
  end

  def list_files(dir, pattern = '*')
    ftp.nlst(File.join(tf_dir, dir, pattern)).collect do |f|
      File.basename(f)
    end
  end

  def upload_configuration(configuration_file, upload_file)
    logger.debug "FTP PUT, CONFIG FILE: #{configuration_file} DESTINATION: #{upload_file}"
    ftp.putbinaryfile(configuration_file, upload_file)
  end

  def copy_to_server(files, destination_dir)
    logger.debug "FTP PUT, FILES: #{files} DESTINATION: #{destination_dir}"
    files.each do |file|
      destination_file = File.join(destination_dir, File.basename(file)).to_s
      ftp.putbinaryfile(file, destination_file)
    end
  end

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
          Raven.capture_exception(e) if Rails.env.production?
        end
      end
    end
    threads.map { |t| t.join(60) }
  end

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

  def make_ftp_connection
    ftp = Net::FTP.new
    ftp.passive = true
    ftp.connect(ip, ftp_port.presence || 21)
    ftp.login(ftp_username, ftp_password)
    ftp
  rescue EOFError
    Rails.logger.error "Got an EOF error on server #{id}: #{name}"
  end

  def ftp_connection_pool_size
    4
  end

  def file_count_per_thread(files)
    (files.size / ftp_connection_pool_size.to_f).ceil
  end
end
