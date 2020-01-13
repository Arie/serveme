# frozen_string_literal: true

class SimraiServer < RemoteServer
  include FtpAccess

  def tv_port
    port.to_i + 1
  end

  def restart
    Rails.logger.info("Attempting web control restart of server #{name}")
    response = connection.post('/billingapi.aspx', tcadmin_username: SIMRAI_USERNAME,
                                                   tcadmin_password: SIMRAI_PASSWORD,
                                                   function: 'RestartByBillingId',
                                                   response_type: 'text',
                                                   client_package_id: billing_id)

    if response.body =~ /Exception/
      Rails.logger.error "Simrai TCAdmin responded with #{response.body}"
    else
      Rails.logger.info("Simrai restart response: #{response.body}")
    end
  end

  def connection
    @connection ||= Faraday.new(url: 'http://eu.simraicontrol.com', headers: { accept_encoding: 'none' }) do |faraday|
      faraday.request  :url_encoded
      faraday.response :logger
      faraday.adapter  Faraday.default_adapter
    end
  end
end
