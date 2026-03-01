# typed: strict
# frozen_string_literal: true

class DockerHost < ActiveRecord::Base
  extend T::Sig

  belongs_to :location
  validates :city, :ip, presence: true
  validates :start_port, numericality: { greater_than_or_equal_to: 27015 }
  scope :active, -> { where(active: true) }

  sig { params(starts_at: T.any(Time, ActiveSupport::TimeWithZone), ends_at: T.any(Time, ActiveSupport::TimeWithZone)).returns(Integer) }
  def container_count_during(starts_at, ends_at)
    Reservation.joins(:server)
      .where(servers: { type: "CloudServer", cloud_provider: "remote_docker", cloud_location: id.to_s })
      .where.not(servers: { cloud_status: "destroyed" })
      .where("reservations.starts_at < ? AND reservations.ends_at > ?", ends_at, starts_at)
      .count
  end

  sig { params(starts_at: T.any(Time, ActiveSupport::TimeWithZone), ends_at: T.any(Time, ActiveSupport::TimeWithZone)).returns(T::Boolean) }
  def full_during?(starts_at, ends_at)
    container_count_during(starts_at, ends_at) >= (max_containers || 4)
  end

  sig { returns(T::Boolean) }
  def full?
    full_during?(Time.current, Time.current)
  end
end
