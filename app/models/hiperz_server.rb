class HiperzServer < RemoteServer

  has_one :hiperz_server_information, :foreign_key => :server_id
  delegate :hiperz_id, :to => :hiperz_server_information

  include FtpAccess

  def restart
    Rails.logger.info("Attempting web control restart of server #{name}")
    uri = URI("http://cp.hiperz.com/api/generic/do.php?gs_id=#{hiperz_id}&api_key=#{HIPERZ_API_KEY}&action=restart")
    response = Net::HTTP.get(uri)
    Rails.logger.info("Hiperz restart response: #{response}")
  end

  def tv_port
    port.to_i + 1
  end

end
