# typed: true
# frozen_string_literal: true

class LeagueRequest
  extend T::Sig

  include ActiveModel::Model
  validates :ip, format: { with: /\A(?:[0-9]{1,3}\.){3}[0-9]{1,3}\Z/ }
  validates :steam_uid, format: { with: /\A765[0-9]{14}\Z/ }

  attr_accessor :ip, :steam_uid, :reservation_ids, :cross_reference, :user, :target

  sig { params(user: User, ip: T.nilable(String), steam_uid: T.nilable(String), reservation_ids: T.nilable(T.any(String, T::Array[Integer])), cross_reference: T.nilable(String)).void }
  def initialize(user, ip: nil, steam_uid: nil, reservation_ids: nil, cross_reference: nil)
    @user = user
    @ip = ip&.gsub(/[[:space:]]/, '')&.split(',')
    @steam_uid = steam_uid&.gsub(/[[:space:]]/, '')&.split(',')
    @reservation_ids =
      if reservation_ids.is_a?(String)
        reservation_ids.presence && reservation_ids.to_s.split(',').map(&:to_i)
      else
        reservation_ids
      end
    @cross_reference = (cross_reference == '1')
  end

  sig { returns(ActiveRecord::Relation) }
  def search
    @target = [@ip, @steam_uid, @reservation_ids].reject(&:blank?).join(', ')
    if @cross_reference
      Rails.logger.info("Cross reference search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_with_cross_reference(ip: @ip, steam_uid: @steam_uid)
    elsif @ip.present?
      Rails.logger.info("IP search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_by_ip(@ip)
    elsif @steam_uid.present?
      Rails.logger.info("Steam ID search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_by_steam_uid(@steam_uid)
    else
      Rails.logger.info("Reservation search started by #{@user.name} (#{@user.uid}) for #{@target}")
      find_by_reservation_ids(@reservation_ids)
    end
  end

  sig { params(ip: T.any(String, T::Array[String])).returns(ActiveRecord::Relation) }
  def find_by_ip(ip)
    maybe_filter_by_reservation_ids(players_query.where(ip: ip))
  end

  sig { params(steam_uid: T.nilable(T.any(String, T::Array[String]))).returns(ActiveRecord::Relation) }
  def find_by_steam_uid(steam_uid)
    maybe_filter_by_reservation_ids(players_query.where(steam_uid: steam_uid))
  end

  sig { params(reservation_ids: T::Array[Integer]).returns(ActiveRecord::Relation) }
  def find_by_reservation_ids(reservation_ids)
    players_query.where(reservation_id: reservation_ids)
  end

  sig { params(ip: T.nilable(T.any(String, T::Array[String])), steam_uid: T.nilable(T.any(String, T::Array[String]))).returns(ActiveRecord::Relation) }
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

  sig { params(results: ActiveRecord::Relation).returns(Hash) }
  def self.lookup_asns(results)
    asns = {}

    results.map(&:ip).uniq.each do |ip|
      asn = begin
        ReservationPlayer.asn(ip) if ip.present?
      rescue MaxMind::GeoIP2::AddressNotFoundError
        nil
      end
      asns[ip] = asn
    end

    asns
  end

  private

  def maybe_filter_by_reservation_ids(query)
    if @reservation_ids
      query.where(reservation_id: @reservation_ids)
    else
      query
    end
  end

  def pluck_uniques(query, to_pluck)
    query.pluck(to_pluck).uniq.compact
  end

  def players_query
    ReservationPlayer.eager_load(:reservation).joins(reservation: :server).where('servers.sdr = ?', false).where('reservation_players.ip not like ?', '169.254.%').order('reservations.starts_at DESC')
  end
end
