# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Admin::MtrTracesController do
  render_views

  let(:admin_user) { create(:user, :admin) }
  let(:source) { MtrSource.new(type: "ssh_server", key: "host.example", label: "host.example", detail: "SSH host · 2 servers", flag: "nl") }

  before do
    allow(MtrSource).to receive(:all).and_return([ source ])
    allow(MtrRunWorker).to receive(:perform_async)
  end

  it "is admin-only" do
    sign_in create(:user)

    get :index

    expect(response).to redirect_to(root_path)
  end

  context "as admin" do
    before { sign_in admin_user }

    it "lists the machines to run from, in both layouts" do
      get :index
      expect(response.body).to include("host.example").and include("SSH host · 2 servers")

      request.cookies[:ui_v2] = "true"
      get :index
      expect(response.body).to include("v2-card").and include("host.example")
    end

    it "paginates the recent traces, 20 per page" do
      21.times do |i|
        MtrTrace.new(target: "192.0.2.#{i + 1}", target_ip: "192.0.2.#{i + 1}", cycles: 10, created_at: i.minutes.ago).save!(validate: false)
      end

      get :index
      expect(response.body).to include("192.0.2.1<").and include("pagination")
      expect(response.body).not_to include("192.0.2.21<")

      get :index, params: { page: 2 }
      expect(response.body).to include("192.0.2.21<")
    end

    it "queues one run per selected machine and redirects to the trace" do
      post :create, params: { target: "203.0.113.42", cycles: "30", source_ids: [ source.id ] }

      trace = MtrTrace.last
      expect(trace).to have_attributes(target_ip: "203.0.113.42", cycles: 30, user: admin_user)
      expect(trace.runs.map(&:source_key)).to eq([ "host.example" ])
      expect(MtrRunWorker).to have_received(:perform_async).with(trace.runs.first.id)
      expect(response).to redirect_to(admin_mtr_trace_path(trace))
    end

    [ "1.1.1.1; reboot", "$(reboot)", "1.1.1.0/24", "::1", "" ].each do |target|
      it "rejects the target #{target.inspect}" do
        post :create, params: { target: target, cycles: "10", source_ids: [ source.id ] }

        expect(response).to have_http_status(:unprocessable_content)
        expect(MtrTrace.count).to eq(0)
        expect(MtrRunWorker).not_to have_received(:perform_async)
      end
    end

    it "rejects unknown machines and unsupported cycle counts" do
      post :create, params: { target: "203.0.113.42", cycles: "10", source_ids: [ "ssh_server:evil.example" ] }
      expect(response).to have_http_status(:unprocessable_content)

      post :create, params: { target: "203.0.113.42", cycles: "100000", source_ids: [ source.id ] }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "shows a trace with live and finished runs" do
      trace = MtrTrace.create!(target: "203.0.113.42", cycles: 10, user: admin_user,
                               runs: [ MtrRun.new(source_type: "ssh_server", source_key: "host.example", source_label: "host.example", status: "running") ])
      hosts = [ { "ip" => "203.0.113.42", "asn" => 1136, "org" => "KPN", "city" => "Amsterdam", "country" => "NL" } ]
      trace.runs.first.update!(hops: [ { "n" => 1, "hosts" => hosts, "sent" => 4, "received" => 3, "loss" => 25.0, "last" => 9.1, "avg" => 9.0, "best" => 8.0, "worst" => 11.0, "stdev" => 1.0 } ])

      get :show, params: { id: trace.id }

      expect(response.body).to include("AS1136 KPN").and include("25.0%").and include("cycle 4 / 10").and include("Provisional")
    end

    it "gives hops an escaped ASN tooltip and finished runs a copyable text report" do
      trace = MtrTrace.create!(target: "203.0.113.42", cycles: 10,
                               runs: [ MtrRun.new(source_type: "ssh_server", source_key: "host.example", source_label: "host.example", status: "done", finished_at: Time.current) ])
      hosts = [ { "ip" => "203.0.113.42", "asn" => 1136, "org" => "<b>KPN</b>", "net" => "203.0.113.0/24", "city" => nil, "country" => "NL" } ]
      trace.runs.first.update!(hops: [ { "n" => 1, "hosts" => hosts, "sent" => 10, "received" => 10, "loss" => 0.0, "last" => 9.1, "avg" => 9.0, "best" => 8.0, "worst" => 11.0, "stdev" => 1.0 } ])

      get :show, params: { id: trace.id }

      expect(response.body).to include('data-controller="mtr-tooltips"').and include('data-toggle="tooltip"')
      expect(response.body).to include("NET&lt;/strong&gt; 203.0.113.0/24")
      expect(response.body).not_to include("<b>KPN</b>")
      expect(response.body).to include("mtr_report_#{trace.runs.first.id}_container").and include("Copy report")
    end

    it "re-runs a trace from the same machines" do
      trace = MtrTrace.create!(target: "203.0.113.42", cycles: 10,
                               runs: [ MtrRun.new(source_type: "ssh_server", source_key: "host.example", source_label: "host.example", status: "done") ])

      expect { post :rerun, params: { id: trace.id } }.to change(MtrTrace, :count).by(1)
      expect(response).to redirect_to(admin_mtr_trace_path(MtrTrace.last))
    end
  end
end
