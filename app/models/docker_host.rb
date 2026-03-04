# typed: strict
# frozen_string_literal: true

class DockerHost < ActiveRecord::Base
  extend T::Sig

  VIRTUAL_ID_OFFSET = 1_000_000_000

  belongs_to :location
  validates :city, :ip, presence: true
  validates :start_port, numericality: { greater_than_or_equal_to: 27015 }
  scope :active, -> { where(active: true) }

  sig { returns(Integer) }
  def virtual_server_id
    VIRTUAL_ID_OFFSET + id
  end

  sig { params(server_id: T.any(String, Integer)).returns(T::Boolean) }
  def self.docker_host_id?(server_id)
    server_id.to_i >= VIRTUAL_ID_OFFSET
  end

  sig { params(server_id: T.any(String, Integer)).returns(DockerHost) }
  def self.find_by_virtual_id(server_id)
    find(server_id.to_i - VIRTUAL_ID_OFFSET)
  end

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

  sig { returns(Integer) }
  def current_container_count
    container_count_during(Time.current, Time.current)
  end

  sig { returns(T::Boolean) }
  def full?
    full_during?(Time.current, Time.current)
  end
end
