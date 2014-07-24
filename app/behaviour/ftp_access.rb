module FtpAccess

  require 'net/ftp'

  def demos
    @demos ||= ftp.nlst("#{tf_dir}/*.dem")
  end

  def logs
    @logs ||= ftp.nlst("#{tf_dir}/logs/*.log")
  end

  def list_files(dir)
    ftp.nlst(File.join(tf_dir, dir, "*")).collect do |f|
      File.basename(f)
    end
  end

  def upload_configuration(configuration_file, upload_file)
    logger.info "FTP PUT, CONFIG FILE: #{configuration_file} DESTINATION: #{upload_file}"
    ftp.putbinaryfile(configuration_file, upload_file)
  end

  def copy_to_server(files, destination_dir)
    logger.info "FTP PUT, FILES: #{files} DESTINATION: #{destination_dir}"
    files.each do |file|
      destination_file = File.join(destination_dir, File.basename(file)).to_s
      ftp.putbinaryfile(file, destination_file)
    end
  end

  def copy_from_server(files, destination)
    logger.info "FTP GET, FILES: #{files} DESTINATION: #{destination}"
    threads = []
    files.each_slice(4) do |files_for_thread|
      threads << Thread.new do
        ftp = make_ftp_connection
        files_for_thread.each do |file|
          begin
            ftp.getbinaryfile(file, File.join(destination, File.basename(file)))
          rescue
            Rails.logger.error "couldn't download file: #{file}"
          end
        end
      end
    end
    threads.map { |t| t.join(30) }
  end

  def delete_from_server(files)
    threads = []
    files.each_slice(4) do |files_for_thread|
      threads << Thread.new do
        ftp = make_ftp_connection
        files_for_thread.each do |file|
          begin
            ftp.send(:delete, file.shellescape)
          rescue Net::FTPPermError
            Rails.logger.error "couldn't delete file: #{file.shellescape}"
          end
        end
      end
    end
    threads.map { |t| t.join(30) }
  end

  def zip_file_creator_class
    FtpZipFileCreator
  end

  def ftp
    @ftp ||= make_ftp_connection
  end

  def make_ftp_connection
    ftp = Net::FTP.new
    ftp.connect(ip, ftp_port.presence || 21)
    ftp.login(ftp_username, ftp_password)
    ftp
  end

end
