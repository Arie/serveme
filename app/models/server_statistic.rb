# frozen_string_literal: true

class ServerStatistic < ActiveRecord::Base
  belongs_to :reservation
  belongs_to :server

  after_create_commit -> { broadcast_replace_to server, target: server, partial: 'servers/server_admin_info', locals: { server: server } }
end
