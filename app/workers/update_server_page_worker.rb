# frozen_string_literal: true

class UpdateServerPageWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    servers = Server.active.includes([current_reservations: { user: :groups }], :location, :recent_server_statistics).order(:name)
    Turbo::StreamsChannel.broadcast_replace_to 'server-list', target: 'server-list', partial: 'servers/list', locals: { servers: servers }
    Turbo::StreamsChannel.broadcast_replace_to 'admin-server-list', target: 'admin-server-list', partial: 'servers/admin_list', locals: { servers: servers }
  end
end
