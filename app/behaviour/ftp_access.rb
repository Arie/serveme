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
    destination = File.join(tf_dir, destination_dir)
    logger.info "FTP PUT, FILES: #{files} DESTINATION: #{destination}"
    files.each do |file|
      destination_file = File.join(destination, File.basename(file)).to_s
      ftp.putbinaryfile(file, destination_file)
    end
  end

  def copy_from_server(files, destination)
    logger.info "FTP GET, FILES: #{files} DESTINATION: #{destination}"
    files.each do |file|
      ftp.getbinaryfile(file, File.join(destination, File.basename(file)))
    end
  end

  def delete_from_server(files)
    files.each do |file|
      begin
        ftp.send(:delete, file.shellescape)
      rescue Net::FTPPermError
        Rails.logger.error "couldn't delete file: #{file.shellescape}"
      end
    end
  end

  def zip_file_creator_class
    FtpZipFileCreator
  end

  def ftp
    @ftp ||= begin
               ftp = Net::FTP.new(ip, ftp_username, ftp_password)
               ftp.passive = true
               ftp
             end
  end
end
