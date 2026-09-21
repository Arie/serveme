# typed: false
# frozen_string_literal: true

require "spec_helper"

describe MtrRunWorker do
  let(:trace) { MtrTrace.new(target: "1.1.1.1", target_ip: "1.1.1.1", cycles: 10).tap { |t| t.save!(validate: false) } }
  let(:run) { trace.runs.create!(source_type: "ssh_server", source_key: "host.example", source_label: "host.example") }
  let(:source) { instance_double(MtrSource) }
  let(:redis) { double("redis", set: true, del: 1) }
  let(:raw) { File.read(Rails.root.join("spec/fixtures/mtr/raw_1_1_1_1.txt")) }

  before do
    allow(MtrSource).to receive(:find).with("ssh_server", "host.example").and_return(source)
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(BetaBroadcast).to receive(:replace)
    allow(ReservationPlayer).to receive(:asn).and_return(double(autonomous_system_number: 13_335, autonomous_system_organization: "Cloudflare", network: "1.1.1.0/24"))
    allow(Geocoder).to receive(:search).and_return([ double(city: "Frankfurt", country_code: "DE") ])
  end

  it "runs only the IPAddr-normalised target through the shell" do
    expect(source).to receive(:stream).with("timeout 40 mtr --raw -n -c 10 1.1.1.1").and_return(0)

    described_class.new.perform(run.id)
  end

  it "stores enriched hops from output that arrives in arbitrary chunks" do
    allow(source).to receive(:stream) do |_command, &block|
      raw.scan(/.{1,7}/m).each { |chunk| block.call(:stdout, chunk) }
      0
    end

    described_class.new.perform(run.id)

    run.reload
    expect(run.status).to eq("done")
    expect(run.hops.size).to eq(8)
    expect(run.hops.last["hosts"].first).to include("ip" => "1.1.1.1", "asn" => 13_335, "net" => "1.1.1.0/24", "city" => "Frankfurt")
    expect(run.hops.first).to include("sent" => 3, "loss" => 0.0)
    expect(run.raw_output).to eq(raw)
    expect(run.finished_at).to be_present
  end

  it "broadcasts while output is still arriving" do
    allow(source).to receive(:stream) do |_command, &block|
      block.call(:stdout, "x 0 1\nh 0 1.1.1.1\np 0 900 1\n")
      expect(run.reload.status).to eq("running")
      expect(run.hops.size).to eq(1)
      0
    end

    described_class.new.perform(run.id)
  end

  it "broadcasts the other machines' current state" do
    run
    other = trace.runs.create!(source_type: "ssh_server", source_key: "other.example", source_label: "other.example")
    seen = []
    allow(BetaBroadcast).to receive(:replace) do |_stream, **rendering|
      locals = rendering[:locals]
      seen << (locals[:trace] || locals[:run].mtr_trace).runs.map { |r| [ r.source_label, r.status ] }
    end
    allow(source).to receive(:stream) do |_command, &block|
      MtrRun.find(other.id).update!(status: "running")
      block.call(:stdout, "x 0 1\nh 0 1.1.1.1\np 0 900 1\n")
      MtrRun.find(other.id).update!(status: "done")
      0
    end

    described_class.new.perform(run.id)

    expect(seen.last).to eq([ [ "host.example", "done" ], [ "other.example", "done" ] ])
    expect(seen).to include([ [ "host.example", "running" ], [ "other.example", "running" ] ])
  end

  it "marks the run unreachable when the SSH connection fails" do
    allow(source).to receive(:stream).and_raise(Net::SSH::ConnectionTimeout)

    described_class.new.perform(run.id)

    expect(run.reload).to have_attributes(status: "unreachable", error: /ConnectionTimeout/)
  end

  it "explains a missing mtr binary" do
    allow(source).to receive(:stream).and_return(127)

    described_class.new.perform(run.id)

    expect(run.reload).to have_attributes(status: "failed", error: /not installed/)
  end

  it "keeps partial hops when the remote timeout fires" do
    allow(source).to receive(:stream) do |_command, &block|
      block.call(:stdout, "x 0 1\nh 0 10.0.0.1\np 0 900 1\n")
      124
    end

    described_class.new.perform(run.id)

    expect(run.reload).to have_attributes(status: "failed", error: /Timed out/)
    expect(run.hops.size).to eq(1)
  end

  it "refuses to run twice from one machine at the same time" do
    allow(redis).to receive(:set).and_return(nil)
    expect(source).not_to receive(:stream)

    described_class.new.perform(run.id)

    expect(run.reload).to have_attributes(status: "failed", error: /already running/)
  end

  it "marks the run failed when the machine is no longer a source" do
    allow(MtrSource).to receive(:find).and_return(nil)

    described_class.new.perform(run.id)

    expect(run.reload.status).to eq("failed")
  end
end
