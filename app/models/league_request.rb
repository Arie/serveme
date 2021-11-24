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
    elsif @ip.present?
      Rails.logger.info("IP search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_by_ip(@ip)
    else
      Rails.logger.info("Steam ID search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_by_steam_uid(@steam_uid)
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
      ips = pluck_uniques(find_by_steam_uid(steam_uid), :ip)
      steam_uids = pluck_uniques(find_by_ip(ip), :steam_uid)
      find_by_steam_uid(steam_uids).or(find_by_ip(ips))
    elsif ip.present?
      steam_uids = pluck_uniques(find_by_ip(ip), :steam_uid)
      find_by_steam_uid(steam_uids)
    else
      ips = pluck_uniques(find_by_steam_uid(steam_uid), :ip)
      find_by_ip(ips)
    end
  end

  private

  def pluck_uniques(query, to_pluck)
    query.pluck(to_pluck).uniq.reject(&:nil?)
  end

  def players_query
    ReservationPlayer.joins(reservation: :server).where('servers.sdr = ?', false).order('reservations.starts_at DESC')
  end
end
