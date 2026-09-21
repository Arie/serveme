# typed: false
# frozen_string_literal: true

require "spec_helper"

describe MtrRawParser do
  subject(:parser) { described_class.new(target: "1.1.1.1") }

  define_method(:feed) do |*lines|
    lines.each { |l| parser << l }
  end

  context "with a real mtr 0.95 capture" do
    before { File.foreach(Rails.root.join("spec/fixtures/mtr/raw_1_1_1_1.txt")) { |l| parser << l } }

    it "numbers hops from 1 and ends the path at the target" do
      hops = parser.hops(final: true)

      expect(hops.map { |h| h[:n] }).to eq((1..8).to_a)
      expect(hops.last[:ips]).to eq([ "1.1.1.1" ])
    end

    it "computes per-hop stats in milliseconds" do
      hop = parser.hops(final: true).first

      expect(hop).to include(sent: 3, received: 3, loss: 0.0)
      expect(hop[:best]).to be <= hop[:avg]
      expect(hop[:avg]).to be <= hop[:worst]
      expect(hop[:avg]).to be < 5
    end
  end

  it "converts microseconds to milliseconds" do
    feed "x 0 1", "h 0 10.0.0.1", "p 0 12345 1", "x 0 2", "p 0 20000 2"

    expect(parser.hops(final: true).first).to include(last: 20.0, best: 12.3, worst: 20.0, avg: 16.2, stdev: 3.8)
  end

  it "counts unanswered probes as loss" do
    feed "x 0 1", "h 0 10.0.0.1", "p 0 1000 1", "x 0 2", "x 0 3", "x 0 4", "p 0 1000 4"

    expect(parser.hops(final: true).first).to include(sent: 4, received: 2, loss: 50.0)
  end

  it "does not count the probe still in flight as lost while live" do
    feed "x 0 1", "h 0 10.0.0.1", "p 0 1000 1", "x 0 2"

    expect(parser.hops(final: false).first).to include(sent: 1, loss: 0.0)
    expect(parser.hops(final: true).first).to include(sent: 2, loss: 50.0)
  end

  it "keeps every address of a load-balanced hop" do
    feed "x 0 1", "h 0 10.0.0.1", "p 0 1000 1", "x 0 2", "h 0 10.0.0.2", "h 0 10.0.0.1", "p 0 1000 2"

    expect(parser.hops(final: true).first[:ips]).to eq([ "10.0.0.1", "10.0.0.2" ])
  end

  it "reports silent hops between replying ones" do
    feed "x 0 1", "h 0 10.0.0.1", "p 0 1000 1", "x 1 2", "x 2 3", "h 2 1.1.1.1", "p 2 1000 3"

    silent = parser.hops(final: true)[1]
    expect(silent).to include(n: 2, ips: [], received: 0, loss: 100.0, avg: nil)
  end

  it "keeps only one trailing silent hop when the target never replies" do
    feed "x 0 1", "h 0 10.0.0.1", "p 0 1000 1", "x 1 2", "x 2 3", "x 3 4"

    expect(parser.hops(final: true).map { |h| h[:n] }).to eq([ 1, 2 ])
  end

  it "ignores lines it does not understand" do
    feed "", "d 0 router.example", "garbage", "p x y"

    expect(parser.hops(final: true)).to eq([])
  end
end
