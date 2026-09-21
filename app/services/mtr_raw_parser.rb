# typed: true
# frozen_string_literal: true

# Incremental parser for `mtr --raw` (0.95) output:
#   x <hop> <seq>         probe sent
#   h <hop> <ip>          hop address (repeats; several per hop under ECMP)
#   p <hop> <usec> <seq>  reply
class MtrRawParser
  extend T::Sig

  HopState = Struct.new(:ips, :sent, :rtts)

  sig { params(target: String).void }
  def initialize(target:)
    @target = target
    @hops = T.let(Hash.new { |h, k| h[k] = HopState.new([], [], {}) }, T::Hash[Integer, T.untyped])
  end

  sig { params(line: String).returns(T.self_type) }
  def <<(line)
    kind, hop, a, b = line.split
    return self unless hop&.match?(/\A\d+\z/)

    state = @hops[hop.to_i]
    case kind
    when "x" then state.sent << a.to_i if a
    when "h" then state.ips << a if a && !state.ips.include?(a)
    when "p" then state.rtts[b.to_i] = a.to_i / 1000.0 if a&.match?(/\A\d+\z/) && b
    else @hops.delete(hop.to_i) if state.sent.empty? && state.ips.empty?
    end
    self
  end

  # final: false leaves the newest unanswered probe of each hop out of the loss
  # figure, because it is most likely still in flight.
  sig { params(final: T::Boolean).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def hops(final:)
    path.map { |index| hop_stats(index, @hops[index], final) }
  end

  private

  # mtr probes one hop past the target before it knows the path length, and
  # keeps probing silent hops up to max-ttl when the target never answers.
  def path
    indexes = @hops.keys.sort
    target_index = indexes.find { |i| @hops[i].ips.include?(@target) }
    return indexes.select { |i| i <= target_index } if target_index

    last_reply = indexes.reverse.find { |i| @hops[i].ips.any? }
    return [] unless last_reply

    indexes.select { |i| i <= last_reply + 1 }
  end

  def hop_stats(index, state, final)
    sent = state.sent
    sent = sent[0...-1] if !final && sent.any? && !state.rtts.key?(sent.last)
    rtts = state.rtts.values
    received = rtts.size

    {
      n: index + 1,
      ips: state.ips.dup,
      sent: sent.size,
      received: received,
      loss: sent.empty? ? 0.0 : ((sent.size - received) * 100.0 / sent.size).round(1).clamp(0.0, 100.0),
      last: rtts.last&.round(1),
      avg: rtts.any? ? (rtts.sum / received).round(1) : nil,
      best: rtts.min&.round(1),
      worst: rtts.max&.round(1),
      stdev: rtts.any? ? stdev(rtts).round(1) : nil
    }
  end

  def stdev(values)
    mean = values.sum / values.size
    Math.sqrt(values.sum { |v| (v - mean)**2 } / values.size)
  end
end
