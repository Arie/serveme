# frozen_string_literal: true

class InactiveServersCheckerWorker
  include Sidekiq::Worker

  def perform(server_ids)
    server_ids.each do |server_id|
      InactiveServerCheckerWorker.perform_async(server_id)
    end
  end
end
