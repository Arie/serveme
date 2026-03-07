# typed: strict
# frozen_string_literal: true

class SiteSetting < ActiveRecord::Base
  extend T::Sig

  validates :key, presence: true, uniqueness: true

  sig { params(key: String).returns(T.nilable(String)) }
  def self.get(key)
    Rails.cache.fetch("site_setting:#{key}", expires_in: 1.minute) do
      find_by(key: key)&.value
    end
  end

  sig { params(key: String, value: T.nilable(String)).void }
  def self.set(key, value)
    setting = find_or_initialize_by(key: key)
    setting.value = value
    setting.save!
    Rails.cache.delete("site_setting:#{key}")
  end

  sig { params(key: String).returns(T::Boolean) }
  def self.enabled?(key)
    get(key) == "true"
  end

  sig { returns(T.nilable(Integer)) }
  def self.free_server_limit
    val = get("free_server_limit")
    val&.to_i
  end

  sig { params(user: User, starts_at: T.any(Time, ActiveSupport::TimeWithZone), ends_at: T.any(Time, ActiveSupport::TimeWithZone)).returns(T::Boolean) }
  def self.free_server_limit_reached?(user, starts_at, ends_at)
    return false if user.donator?

    limit = free_server_limit
    return false unless limit

    free_user_reservation_count(starts_at, ends_at) >= limit
  end

  sig { params(starts_at: T.any(Time, ActiveSupport::TimeWithZone), ends_at: T.any(Time, ActiveSupport::TimeWithZone)).returns(Integer) }
  def self.free_user_reservation_count(starts_at, ends_at)
    donator_user_ids = Group.donator_group.users.select(:id)

    Reservation
      .where("reservations.starts_at < ? AND reservations.ends_at > ?", ends_at, starts_at)
      .where.not(user_id: donator_user_ids)
      .count
  end

  sig { returns(Integer) }
  def self.free_servers_available
    limit = free_server_limit
    return 0 unless limit

    in_use = free_user_reservation_count(Time.current, Time.current)
    [ limit - in_use, 0 ].max
  end

  sig { returns(T::Boolean) }
  def self.always_enable_plugins?
    enabled?("always_enable_plugins")
  end

  sig { returns(T::Boolean) }
  def self.always_enable_demos_tf?
    enabled?("always_enable_demos_tf")
  end

  sig { returns(T::Boolean) }
  def self.show_democheck?
    enabled?("show_democheck")
  end
end
