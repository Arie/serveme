# typed: false
# frozen_string_literal: true

require "spec_helper"

describe MtrTraceAnalysis do
  let(:trace) { MtrTrace.new(target: "203.0.113.42", target_ip: "203.0.113.42", cycles: 10).tap { |t| t.save!(validate: false) } }

  define_method(:hop) do |n, ip, loss, asn: 64_500, org: "Net"|
    hosts = ip ? [ { "ip" => ip, "asn" => asn, "org" => org, "city" => nil, "country" => nil } ] : []
    { "n" => n, "hosts" => hosts, "sent" => 10, "received" => 10 - (loss / 10), "loss" => loss.to_f,
      "last" => 1.0, "avg" => 1.0, "best" => 1.0, "worst" => 1.0, "stdev" => 0.0 }
  end

  define_method(:add_run) do |label, hops, status: "done"|
    trace.runs.create!(source_type: "ssh_server", source_key: label, source_label: label, status: status, hops: hops)
  end

  define_method(:lossy_path) do |first_ip|
    [ hop(1, first_ip, 0), hop(2, "198.51.100.1", 20, asn: 64_501), hop(3, "198.51.100.9", 20, asn: 64_502), hop(4, "203.0.113.42", 20, asn: 64_503) ]
  end

  describe "hop severity" do
    it "only flags loss that persists to the end of the path" do
      run = add_run("a", [ hop(1, "192.0.2.1", 60), hop(2, "192.0.2.2", 0), hop(3, "192.0.2.3", 3), hop(4, "203.0.113.42", 20) ])

      expect(described_class.new(trace).hops_for(run).map(&:severity)).to eq(%w[ignored none warn bad])
    end

    it "does not let a silent hop break persistence" do
      run = add_run("a", [ hop(1, "192.0.2.1", 20), hop(2, nil, 100), hop(3, "203.0.113.42", 20) ])

      expect(described_class.new(trace).hops_for(run).map(&:severity)).to eq(%w[bad none bad])
    end
  end

  describe "shared hops and AS handoffs" do
    it "counts public hops seen on several paths, but never the target or private hops" do
      a = add_run("a", [ hop(1, "10.0.0.1", 0, asn: nil), hop(2, "198.51.100.1", 0), hop(3, "203.0.113.42", 0) ])
      add_run("b", [ hop(1, "10.0.0.1", 0, asn: nil), hop(2, "198.51.100.1", 0), hop(3, "203.0.113.42", 0) ])

      expect(described_class.new(trace).hops_for(a).map(&:shared)).to eq([ nil, 2, nil ])
    end

    it "marks the hop where the AS changes" do
      run = add_run("a", [ hop(1, "192.0.2.1", 0, asn: 1), hop(2, "10.0.0.1", 0, asn: nil), hop(3, "192.0.2.2", 0, asn: 1), hop(4, "203.0.113.42", 0, asn: 2) ])

      expect(described_class.new(trace).hops_for(run).map(&:handoff)).to eq([ false, false, false, true ])
    end
  end

  describe "#verdict" do
    it "waits while nothing has finished" do
      add_run("a", [], status: "running")

      expect(described_class.new(trace).verdict).to include(level: "pending", provisional: true)
    end

    it "reports a clean result" do
      add_run("a", [ hop(1, "192.0.2.1", 0), hop(2, "203.0.113.42", 0) ])

      expect(described_class.new(trace).verdict).to include(level: "ok", provisional: false, text: "The path is clean end-to-end.")
    end

    it "names the shared hop where loss starts and clears shared hops that are clean elsewhere" do
      add_run("a", lossy_path("192.0.2.1"))
      add_run("b", lossy_path("192.0.2.2"))
      add_run("c", [ hop(1, "192.0.2.3", 0), hop(2, "198.51.100.9", 0, asn: 64_502), hop(3, "203.0.113.42", 0, asn: 64_503) ])

      verdict = described_class.new(trace).verdict

      expect(verdict[:level]).to eq("bad")
      expect(verdict[:text]).to include("2 of 3 paths lose packets end-to-end")
      expect(verdict[:text]).to include("198.51.100.1")
      expect(verdict[:text]).not_to include("198.51.100.9 (")
    end

    it "points at the target side when every path is lossy with nothing in common" do
      add_run("a", [ hop(1, "192.0.2.1", 0), hop(2, "203.0.113.42", 20) ])
      add_run("b", [ hop(1, "192.0.2.2", 0), hop(2, "203.0.113.42", 20) ])

      expect(described_class.new(trace).verdict[:text]).to include("at or near the target")
    end

    it "reports paths that never reach the target" do
      add_run("a", [ hop(1, "192.0.2.1", 0), hop(2, nil, 100) ])

      expect(described_class.new(trace).verdict).to include(level: "bad")
      expect(described_class.new(trace).verdict[:text]).to include("never reached the target")
    end

    it "stays provisional until every run has finished" do
      add_run("a", [ hop(1, "192.0.2.1", 0), hop(2, "203.0.113.42", 0) ])
      add_run("b", [], status: "running")

      expect(described_class.new(trace).verdict).to include(provisional: true, text: "No end-to-end loss on the 1 of 2 paths that finished.")
    end

    it "does not call a failed machine clean" do
      add_run("a", [ hop(1, "192.0.2.1", 0), hop(2, "203.0.113.42", 0) ])
      add_run("b", [], status: "failed")

      expect(described_class.new(trace).verdict[:text]).to eq("No end-to-end loss on the 1 of 2 paths that finished.")
    end
  end
end
