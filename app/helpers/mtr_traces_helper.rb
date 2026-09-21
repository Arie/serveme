# typed: false
# frozen_string_literal: true

module MtrTracesHelper
  MTR_UI = {
    classic: { heading: "mb-1", card: "card mb-3", body: "card-body", title: "card-title", table: "table table-sm mb-0", table_wrap: "table-responsive",
               label: "form-label", input: "form-control", select: "form-control", primary: "btn btn-primary", button: "btn btn-secondary btn-sm",
               badge: "badge", badges: { "ok" => "bg-success text-white", "none" => "bg-success text-white", "warn" => "bg-warning text-dark", "bad" => "bg-danger text-white" }, badge_default: "bg-secondary text-white" },
    v2: { heading: "v2-page-title", card: "v2-card mb-3", body: "", title: "font-display text-ink mb-3", table: "v2-table", table_wrap: "v2-table-wrap",
          label: "v2-label", input: "v2-input", select: "v2-select", primary: "v2-btn v2-btn-primary", button: "v2-btn v2-btn-sm v2-btn-outline",
          badge: "v2-badge", badges: { "ok" => "v2-badge-success", "none" => "v2-badge-success", "warn" => "v2-badge-gold", "bad" => "v2-badge-danger" }, badge_default: "" }
  }.freeze

  # The partials are shared between the classic and the beta layout. Only the
  # wrapper classes differ.
  def mtr_ui(key)
    MTR_UI.fetch(request&.variant&.include?(:v2) ? :v2 : :classic).fetch(key)
  end

  def mtr_badge(level)
    [ mtr_ui(:badge), mtr_ui(:badges).fetch(level.to_s, mtr_ui(:badge_default)) ].join(" ")
  end

  # Same Bootstrap tooltip as the league request ASN column. Values come from
  # MaxMind and the network, so they are escaped before going into html: true.
  def mtr_hop_tooltip(hop, stats: false)
    host = hop.host
    lines = [ [ "IP", hop.ip ], [ "ASN", hop.asn ], [ "ORG", host["org"] ], [ "NET", host["net"] ], [ "LOC", hop.place ] ]
    lines += [ [ "LOSS", "#{hop.loss}%" ], [ "AVG", "#{mtr_ms(hop.avg)} ms" ], [ "PATHS", hop.shared ] ] if stats
    html = lines.select { |_, value| value.present? }.map { |label, value| "<strong>#{label}</strong> #{ERB::Util.html_escape(value)}" }.join("<br>")
    { title: html, data: { toggle: "tooltip", html: true, placement: "top" } }
  end

  def mtr_flag(flag)
    tag.span(class: [ "flags", "flags-#{flag}" ]) if flag.present?
  end

  def mtr_ms(value)
    value.nil? ? "–" : format("%.1f", value)
  end

  def mtr_range_style(hop, scale)
    left = (hop.best / scale * 100).clamp(0, 100)
    right = (hop.worst / scale * 100).clamp(0, 100)
    { span: "left:#{left.round(1)}%;width:#{[ right - left, 1 ].max.round(1)}%", avg: "left:#{(hop.avg / scale * 100).clamp(0, 99).round(1)}%" }
  end

  # Latency bars share one scale per run so hops are comparable.
  def mtr_scale(hops)
    [ hops.filter_map(&:worst).max.to_f, 10.0 ].max
  end

  def mtr_text_report(run, hops)
    lines = [ format("%-3s %-40s %6s %4s %7s %7s %7s %7s %6s", "#", "Host", "Loss%", "Snt", "Last", "Avg", "Best", "Wrst", "StDev") ]
    hops.each do |hop|
      host = hop.silent? ? "???" : [ hop.ip, hop.network ].compact.join("  ")
      lines << format("%-3d %-40s %5.1f%% %4d %7s %7s %7s %7s %6s", hop.n, host.truncate(40), hop.loss, hop.sent,
                      mtr_ms(hop.last), mtr_ms(hop.avg), mtr_ms(hop.best), mtr_ms(hop.worst), mtr_ms(hop.stdev))
    end
    "mtr from #{run.source_label} to #{run.mtr_trace.target_ip}, #{run.mtr_trace.cycles} cycles, #{run.finished_at&.utc&.to_fs(:db)} UTC\n#{lines.join("\n")}"
  end
end
