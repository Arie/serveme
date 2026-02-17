# typed: true
# frozen_string_literal: true

class UpdateServerPageWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  LOCK_KEY = "update_server_page_worker"

  def perform
    $lock.synchronize(LOCK_KEY, expiry: 30, retries: 1, initial_wait: 0) do
      servers = Server.active.includes([ current_reservations: { user: :groups } ], :location, :recent_server_statistics).order(:name)
      Turbo::StreamsChannel.broadcast_replace_to "server-list", target: "server-list", partial: "servers/list", locals: { servers: servers }
      Turbo::StreamsChannel.broadcast_replace_to "admin-server-list", target: "admin-server-list", partial: "servers/admin_list", locals: { servers: servers, latest_server_version: Server.latest_version }
    end
  rescue RemoteLock::Error
    # Another instance is already running, skip
  end
end
