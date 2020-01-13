# frozen_string_literal: true

class LeagueRequest
  include ActiveModel::Model
  validates :ip, format: { with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\Z/ }
  validates :steam_uid, format: { with: /\A765[0-9]{14}\Z/ }

  attr_accessor :ip, :steam_uid, :cross_reference, :user, :target

  def initialize(user, ip: nil, steam_uid: nil, cross_reference: nil)
    @user = user
    @ip = ip&.gsub(/[[:space:]]/, '')&.split(',')
    @steam_uid = steam_uid&.gsub(/[[:space:]]/, '')&.split(',')
    @cross_reference = (cross_reference == '1')
  end

  def search
    @target = [@ip, @steam_uid].reject(&:blank?).join(', ')
    if @cross_reference
      Rails.logger.info("Cross reference search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_with_cross_reference(ip: @ip, steam_uid: @steam_uid)
    else
      if @ip.present?
        Rails.logger.info("IP search started by #{@user.name} (#{@user.uid}) for #{@target}")
        find_by_ip(@ip)
      else
        Rails.logger.info("Steam ID search started by #{@user.name} (#{@user.uid}) for #{@target}")
        find_by_steam_uid(@steam_uid)
      end
    end
  end

  def find_by_ip(ip)
    players_query.where(ip: ip)
  end

  def find_by_steam_uid(steam_uid)
    players_query.where(steam_uid: steam_uid)
  end

  def find_with_cross_reference(ip: nil, steam_uid: nil)
    if ip.present? && steam_uid.present?
      ips = find_by_steam_uid(steam_uid).pluck(:ip).uniq.reject(&:nil?)
      steam_uids = find_by_ip(ip).pluck(:steam_uid).uniq.reject(&:nil?)
      find_by_steam_uid(steam_uids).or(find_by_ip(ips))
    elsif ip.present?
      steam_uids = find_by_ip(ip).pluck(:steam_uid).uniq.reject(&:nil?)
      find_by_steam_uid(steam_uids)
    else
      ips = find_by_steam_uid(steam_uid).pluck(:ip).uniq.reject(&:nil?)
      find_by_ip(ips)
    end
  end

  private

  def players_query
    ReservationPlayer.joins(:reservation).where('reservations.starts_at > ?', 1.year.ago).order('reservations.starts_at DESC')
  end
end
