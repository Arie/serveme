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
        if ReservationPlayer.idiotic_name?(nickname)
          ban_idiot(steam_uid)
          rename_user(steam_uid)
        else
          User.find_by(uid: steam_uid).update(nickname: nickname, name: nickname)
        end
      rescue SteamCondenser::Error => exception
        Rails.logger.info "Couldn't query Steam community: #{exception}"
      end
    end
  end

  def idiot?(nickname)
    nickname.include?("﷽")
  end

  def ban_idiot(steam_uid)
    uid3 = SteamCondenser::Community::SteamId.community_id_to_steam_id3(steam_uid.to_i)
    Server.active.each do |s|
      s.rcon_exec "banid 0 #{uid3} kick"
    end
  end

  def rename_user(steam_uid)
    User.find_by_uid(steam_uid)&.update(nickname: "idiot", name: "idiot")
  end
end
