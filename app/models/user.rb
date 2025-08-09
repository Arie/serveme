# typed: true
# frozen_string_literal: true

require "securerandom"

class User < ActiveRecord::Base
  extend T::Sig
  devise :omniauthable, :rememberable, :trackable

  has_many :reservations
  has_many :log_uploads, through: :reservations
  has_many :group_users, -> { where(expires_at: nil).or(where(expires_at: Time.current..)) }
  has_many :groups,   through: :group_users
  has_many :servers,  through: :groups
  has_many :orders
  has_many :paypal_orders
  has_many :stripe_orders
  has_many :reservation_players, primary_key: :uid, foreign_key: :steam_uid
  has_many :player_statistics,   primary_key: :uid, foreign_key: :steam_uid
  has_many :vouchers,            foreign_key: :created_by_id
  has_one :file_upload_permission, dependent: :destroy
  geocoded_by :current_sign_in_ip
  before_save :geocode, if: :current_sign_in_ip_changed_and_ipv4?

  sig { params(auth: T.untyped, _signed_in_resource: T.nilable(String)).returns(User) }
  def self.find_for_steam_auth(auth, _signed_in_resource = nil)
    user = User.where(provider: auth.provider, uid: auth.uid).first
    if user
      user.update(name: auth.info.name, nickname: auth.info.nickname)
    else
      user = User.create(name: auth.info.name,
                         nickname: auth.info.nickname,
                         provider: auth.provider,
                         uid: auth.uid)
    end
    user
  end

  sig { returns(String) }
  def steam_profile_url
    "https://steamcommunity.com/profiles/#{uid.to_i}"
  end

  sig { params(size: Symbol).returns(String) }
  def steam_avatar_url(size = :medium)
    steam_id = SteamCondenser::Community::SteamId.new(uid.to_i)
    case size
    when :full
      steam_id.full_avatar_url
    when :medium
      steam_id.medium_avatar_url
    else
      steam_id.medium_avatar_url
    end
  rescue StandardError
    "https://avatars.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_#{size}.jpg" # Default avatar
  end

  sig { returns(T::Boolean) }
  def donator?
    @donator ||= group_ids.include?(Group.donator_group.id)
  end

  sig { returns(T::Boolean) }
  def admin?
    @admin ||= group_ids.include?(Group.admin_group.id)
  end

  sig { returns(T::Boolean) }
  def league_admin?
    @league_admin ||= group_ids.include?(Group.league_admin_group.id)
  end

  sig { returns(T::Boolean) }
  def streamer?
    @streamer ||= group_ids.include?(Group.streamer_group.id)
  end

  sig { returns(T::Boolean) }
  def trusted_api?
    @trusted_api ||= group_ids.include?(Group.trusted_api_group.id)
  end

  sig { returns(T.nilable(T::Boolean)) }
  def banned?
    return false if ReservationPlayer.whitelisted_uid?(uid)

    !!(ReservationPlayer.banned_uid?(uid) || ReservationPlayer.banned_ip?(current_sign_in_ip))
  end

  sig { returns(ActiveSupport::Duration) }
  def maximum_reservation_length
    if admin? || donator?
      10.hours
    else
      2.hours
    end
  end

  sig { returns(ActiveSupport::Duration) }
  def reservation_extension_time
    if donator?
      1.hour
    else
      20.minutes
    end
  end

  sig { returns(T.any(Integer, Float, BigDecimal)) }
  def total_reservation_seconds
    # Use counter cache if available, fallback to calculation
    if has_attribute?(:total_reservation_seconds) && read_attribute(:total_reservation_seconds)&.positive?
      read_attribute(:total_reservation_seconds)
    else
      reservations.sum(:duration)
    end
  end

  sig { returns(T::Boolean) }
  def top10?
    Statistic.top_10_users.key?(self)
  end

  sig { returns(T.nilable(ActiveSupport::TimeWithZone)) }
  def donator_until
    group_users.find_by(group_id: Group.donator_group)&.expires_at
  end

  sig { returns(T::Boolean) }
  def private_server_option?
    @private_server_option ||=
      groups.include?(Group.private_user(self))
  end

  sig { returns(T.nilable(Server)) }
  def private_server
    Group.private_user(self).servers.first
  end

  sig { params(server_id: String).returns(T.nilable(T::Boolean)) }
  def private_server_id=(server_id)
    return unless server_id.to_i.positive?

    group_server = Group.private_user(self).group_servers.first_or_initialize
    group_server.server_id = server_id.to_i
    group_server.save!
  end

  sig { returns(T.nilable(T::Boolean)) }
  def current_sign_in_ip_changed_and_ipv4?
    current_sign_in_ip_ipv4? && current_sign_in_ip_changed?
  end

  sig { returns(T.nilable(T::Boolean)) }
  def current_sign_in_ip_ipv4?
    self[:current_sign_in_ip] && IPAddr.new(self[:current_sign_in_ip]).ipv4?
  end

  sig { returns(T.nilable(Geocoder::Result::Base)) }
  def geocoded
    return unless current_sign_in_ip_ipv4?

    @geocoded ||= Geocoder.search(current_sign_in_ip).try(:first)
  end

  sig { returns(T::Boolean) }
  def from_na?
    na_timezone? || na_sign_in_ip?
  end

  sig { returns(T.nilable(T::Boolean)) }
  def banned_country?
    current_sign_in_ip_ipv4? && ReservationPlayer.banned_country?(current_sign_in_ip.to_s)
  end

  sig { returns(T::Boolean) }
  def na_timezone?
    return false unless time_zone

    [ "US & Canada", "Canada", "Chicago", "New_York", "Los_Angeles", "Denver", "Phoenix", "Halifax", "Goose_Bay", "St_Johns", "Anchorage" ].any? do |zone|
      time_zone&.match(/#{zone}/)
    end
  end

  sig { returns(T::Boolean) }
  def na_sign_in_ip?
    geocoded&.data&.[]("continent")&.[]("code") == "NA"
  end

  sig { params(path: String).returns(T::Boolean) }
  def can_upload_to?(path)
    return true if admin?
    file_upload_permission&.path_allowed?(path) || false
  end

  sig { returns(String) }
  def generate_api_key!
    self.api_key = SecureRandom.hex(16)
    save!
    T.must(api_key)
  end

  sig { returns(String) }
  def self.generate_api_key
    SecureRandom.hex(16)
  end
end
