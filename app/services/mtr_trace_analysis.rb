# typed: true
# frozen_string_literal: true

# Interprets a trace: which loss matters, which hops the paths have in
# common, and the verdict text.
class MtrTraceAnalysis
  extend T::Sig

  BAD_LOSS = 5.0

  Hop = Struct.new(:n, :hosts, :loss, :sent, :last, :avg, :best, :worst, :stdev, :severity, :shared, :handoff, keyword_init: true) do
    def silent? = hosts.empty?
    def host = hosts.first
    def ip = host&.fetch("ip")
    def asn = host&.fetch("asn", nil)

    def network
      return nil if silent?

      asn ? "AS#{asn} #{host['org']}" : (host["org"] || "unknown")
    end

    def place = host && [ host["city"], host["country"] ].compact_blank.join(", ").presence
  end

  sig { params(trace: MtrTrace).void }
  def initialize(trace)
    @trace = trace
    @runs = T.let(trace.runs.to_a, T::Array[MtrRun])
    @shared_counts = T.let(shared_counts, T::Hash[String, Integer])
    @hops = T.let({}, T::Hash[Integer, T::Array[T.untyped]])
  end

  sig { params(run: MtrRun).returns(T::Array[T.untyped]) }
  def hops_for(run)
    @hops[run.id] ||= build_hops(run)
  end

  sig { params(run: MtrRun).returns(T.untyped) }
  def final_hop(run)
    hops_for(run).reverse.find { |h| !h.silent? }
  end

  sig { params(run: MtrRun).returns(T::Boolean) }
  def reached_target?(run)
    final_hop(run)&.hosts&.any? { |h| h["ip"] == @trace.target_ip } || false
  end

  # Home routers often drop mtr's probes, so a target that answers no machine
  # says nothing about the path. It only counts against a path when another
  # machine did reach it.
  sig { returns(T::Boolean) }
  def target_answers?
    @runs.any? { |r| reached_target?(r) }
  end

  # none / warn / bad, for the whole path.
  sig { params(run: MtrRun).returns(String) }
  def level(run)
    final = final_hop(run)
    return "none" unless final
    return "bad" if run.finished? && !reached_target?(run) && target_answers?
    return "none" if final.loss.zero?

    final.loss >= BAD_LOSS ? "bad" : "warn"
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def verdict
    done = @runs.select { |r| r.status == "done" }
    provisional = @runs.any? { |r| !r.finished? }
    return { level: "pending", provisional: true, text: "Waiting for the first result…" } if done.empty? && provisional
    return { level: "bad", provisional: false, text: "No machine could complete the trace." } if done.empty?

    broken = done.select { |r| final_hop(r).nil? || (target_answers? && !reached_target?(r)) }
    lossy = (done - broken).select { |r| final_hop(r).loss.positive? }
    clean = done - broken - lossy

    text = [ headline(done, lossy, broken), culprit(lossy, clean, done), silent_target_note(done - broken) ].compact.join(" ")
    level = if broken.any? || lossy.any? { |r| level(r) == "bad" } then "bad"
    elsif lossy.any? then "warn"
    else "ok"
    end
    { level: level, provisional: provisional, text: text }
  end

  private

  def build_hops(run)
    raw = run.hops
    replying = raw.reject { |h| h["hosts"].blank? }
    prev_asn = T.let(nil, T.nilable(Integer))

    raw.map do |h|
      hosts = h["hosts"] || []
      asn = hosts.first&.fetch("asn", nil)
      handoff = !!(asn && prev_asn && asn != prev_asn)
      prev_asn = asn if asn
      Hop.new(n: h["n"], hosts: hosts, loss: h["loss"].to_f, sent: h["sent"], last: h["last"], avg: h["avg"], best: h["best"],
              worst: h["worst"], stdev: h["stdev"], severity: severity(h, replying), shared: shared(hosts), handoff: handoff)
    end
  end

  # Loss at one hop that is gone further down is the router rate-limiting its
  # ICMP replies. The path is not losing packets.
  def severity(hop, replying)
    return "none" if hop["hosts"].blank? || hop["loss"].to_f.zero?

    downstream = replying.select { |h| h["n"] >= hop["n"] }
    return "ignored" unless downstream.all? { |h| h["loss"].to_f.positive? }

    hop["loss"].to_f >= BAD_LOSS ? "bad" : "warn"
  end

  def shared(hosts)
    hosts.filter_map { |h| @shared_counts[h["ip"]] }.max
  end

  def shared_counts
    @runs.flat_map { |r| public_ips(r.hops) }.tally.select { |_, count| count > 1 }
  end

  def public_ips(hops)
    hops.flat_map { |h| h["hosts"] || [] }.select { |h| h["asn"] }.map { |h| h["ip"] }.uniq - [ @trace.target_ip ]
  end

  def headline(done, lossy, broken)
    parts = []
    parts << "#{count_of(broken, done)} never reached the target#{', although other machines did' if target_answers?}." if broken.any?
    if lossy.any?
      parts << "#{count_of(lossy, done)} #{@runs.size == 1 ? 'loses' : 'lose'} packets #{extent}."
    elsif broken.empty?
      parts << clean_headline(done)
    end
    parts.join(" ")
  end

  def clean_headline(done)
    return "The path is clean #{extent}." if @runs.size == 1
    return "All #{done.size} paths are clean #{extent}." if done.size == @runs.size

    "No loss #{extent} on the #{done.size} of #{@runs.size} paths that finished."
  end

  def extent
    target_answers? ? "end-to-end" : "up to the last hop that replies"
  end

  def silent_target_note(judged)
    return if target_answers? || judged.empty?

    "The target itself does not answer, which is normal for home connections that drop ping."
  end

  def count_of(subset, all)
    @runs.size == 1 ? "The path" : "#{subset.size} of #{all.size} paths"
  end

  def culprit(lossy, clean, done)
    return if lossy.empty?

    clean_ips = clean.flat_map { |r| public_ips(r.hops) }
    suspects = lossy.map { |r| hops_for(r).select { |h| %w[warn bad].include?(h.severity) && h.asn && h.ip != @trace.target_ip } }
    common = suspects.map { |hops| hops.map(&:ip) }.reduce(:&) - clean_ips
    first = suspects.first.find { |h| common.include?(h.ip) }

    if first && lossy.size > 1
      "All #{lossy.size} lossy paths share hop #{first.ip} (#{first.network}) and loss starts at or before it."
    elsif first
      "Loss starts at hop #{first.n}, #{first.ip} (#{first.network})."
    elsif lossy.size == done.size
      "The lossy paths have no faulty hop in common, so the loss is most likely at or near the target."
    end
  end
end
