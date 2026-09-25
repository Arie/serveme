# typed: strict
# frozen_string_literal: true

# Shuffles machines within NEARBY_KM of each other so "first free server" callers
# spread load. Shuffles per machine, not per entry, so a host with 4 servers isn't favored.
class NearbyServerShuffler
  extend T::Sig

  NEARBY_KM = 100

  Candidate = T.type_alias { T.any(Server, DockerHost) }

  sig { params(candidates: T::Array[Candidate]).returns(T::Array[Candidate]) }
  def self.shuffle(candidates)
    groups = T.let([], T::Array[T::Array[Candidate]])
    candidates.each do |candidate|
      group = groups.find { |g| nearby?(T.must(g.first), candidate) }
      group ? group << candidate : groups << [ candidate ]
    end
    groups.flat_map { |group| group.group_by { |c| machine(c) }.values.shuffle.flat_map(&:shuffle) }
  end

  sig { params(a: Candidate, b: Candidate).returns(T::Boolean) }
  def self.nearby?(a, b)
    return false unless a.latitude && a.longitude && b.latitude && b.longitude

    Geocoder::Calculations.distance_between([ a.latitude, a.longitude ], [ b.latitude, b.longitude ], units: :km) <= NEARBY_KM
  end

  sig { params(candidate: Candidate).returns(T.nilable(String)) }
  def self.machine(candidate)
    candidate.is_a?(DockerHost) ? candidate.hostname : candidate.host_hostname
  end
end
