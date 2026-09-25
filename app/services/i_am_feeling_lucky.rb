# typed: true
# frozen_string_literal: true

class IAmFeelingLucky
  extend T::Sig

  sig { returns(User) }
  attr_accessor :user

  sig { params(user: User).void }
  def initialize(user)
    @user = user
  end

  sig { returns(Reservation) }
  def build_reservation
    new_reservation_attributes = {
      starts_at: starts_at,
      ends_at: ends_at
    }
    user.reservations.build(base_attributes.merge(new_reservation_attributes))
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def base_attributes
    prev = previous_reservation
    if prev
      prev.reusable_attributes.merge("server" => best_matching_server, "enable_plugins" => prev.enable_plugins?)
    else
      new_reservation_attributes
    end
  end

  sig { returns(T::Hash[String, T.untyped]) }
  def new_reservation_attributes
    {
      "rcon" => rand(10**5).to_s,
      "password" => rand(10**5).to_s,
      "tv_password" => rand(10**5).to_s,
      "auto_end" => true,
      "server" => best_matching_server
    }
  end

  sig { returns(T.nilable(Reservation)) }
  def previous_reservation
    @previous_reservation ||= user.reservations.joins(:server).where(ends_at: ...Time.current).last
  end

  sig { returns(Server) }
  def previous_server
    @previous_server ||= T.must(T.must(previous_reservation).server)
  end

  sig { returns(T.nilable(Server)) }
  def best_matching_server
    candidate = best_candidate
    candidate if candidate.is_a?(Server)
  end

  sig { returns(T.nilable(DockerHost)) }
  def available_docker_host
    candidate = best_candidate
    candidate if candidate.is_a?(DockerHost)
  end

  # Prefer the machine the user played on last, then their previous location, then any.
  sig { returns(T.nilable(NearbyServerShuffler::Candidate)) }
  def best_candidate
    return @best_candidate if defined?(@best_candidate)

    candidates = NearbyServerShuffler.shuffle(available_servers.to_a + DockerHost.available_during(starts_at, ends_at))
    @best_candidate = T.let(best_candidate_for_previous_server(candidates) || candidates.first, T.nilable(NearbyServerShuffler::Candidate))
  end

  sig { params(candidates: T::Array[NearbyServerShuffler::Candidate]).returns(T.nilable(NearbyServerShuffler::Candidate)) }
  def best_candidate_for_previous_server(candidates)
    return unless previous_reservation

    candidates.find { |c| NearbyServerShuffler.machine(c) == previous_server.host_hostname } ||
      candidates.find { |c| c.location_id == previous_server.location_id }
  end

  sig { returns(ActiveRecord::Relation) }
  def available_servers
    ServerForUserFinder.new(user, starts_at, ends_at).servers.order(:position, :name)
  end

  # Attributes for DockerHostReservationCreator, reusing the same settings the
  # regular lucky reservation would have gotten, minus the server reference.
  sig { returns(ActiveSupport::HashWithIndifferentAccess) }
  def docker_host_reservation_params
    base_attributes.except("server", "server_id").merge(
      "starts_at" => starts_at,
      "ends_at" => ends_at
    ).with_indifferent_access
  end

  sig { returns(ActiveSupport::TimeWithZone) }
  def starts_at
    Time.current
  end

  sig { returns(ActiveSupport::TimeWithZone) }
  def ends_at
    2.hours.from_now
  end
end
