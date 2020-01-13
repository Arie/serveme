# frozen_string_literal: true

class UpdateSteamNicknameWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  attr_accessor :steam_uid

  def perform(steam_uid)
    if steam_uid =~ /^7656\d+$/
      @steam_uid = steam_uid
      begin
        nickname = SteamCondenser::Community::SteamId.new(steam_uid.to_i).nickname
        User.find_by(uid: steam_uid).update(nickname: nickname, name: nickname)
      rescue SteamCondenser::Error => exception
        Rails.logger.info "Couldn't query Steam community: #{exception}"
      end
    end
  end
end
