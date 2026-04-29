# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Admin::DockerHostsController do
  render_views

  let(:admin_user) { create(:user, :admin) }

  before do
    sign_in admin_user
  end

  describe "#index" do
    it "lists all docker hosts" do
      docker_host = create(:docker_host, hostname: "de1.serveme.tf")
      get :index
      expect(response).to be_successful
      expect(response.body).to include("de1.serveme.tf")
    end

    it "shows setup status" do
      create(:docker_host, hostname: "de1.serveme.tf", setup_status: "ready")
      get :index
      expect(response).to be_successful
      expect(response.body).to include("ready")
    end
  end

  describe "#create" do
    let(:location) { create(:location) }

    it "creates a docker host with hostname" do
      expect {
        post :create, params: { docker_host: {
          location_id: location.id,
          city: "Frankfurt",
          ip: "1.2.3.4",
          hostname: "de1.serveme.tf",
          start_port: 27015,
          max_containers: 4,
          active: false
        } }
      }.to change(DockerHost, :count).by(1)

      host = DockerHost.last
      expect(host.hostname).to eq("de1.serveme.tf")
      expect(host.ip).to eq("1.2.3.4")
      expect(host.setup_status).to eq("pending")
      expect(response).to redirect_to(setup_admin_docker_host_path(host))
    end
  end

  describe "#setup" do
    let(:docker_host) { create(:docker_host, hostname: "de1.serveme.tf", setup_status: "pending") }

    it "renders the setup page" do
      get :setup, params: { id: docker_host.id }
      expect(response).to be_successful
      expect(response.body).to include("de1.serveme.tf")
    end
  end

  describe "#run_setup_step" do
    let(:docker_host) { create(:docker_host, hostname: "de1.serveme.tf", setup_status: "pending") }

    %w[create_vm dns ssh provision ssl pull_image].each do |step|
      it "enqueues a DockerHostSetupStepWorker for the #{step.inspect} step instead of running synchronously" do
        expect {
          post :run_setup_step, params: { id: docker_host.id, step: step }, format: :turbo_stream
        }.to change(DockerHostSetupStepWorker.jobs, :size).by(1)
        expect(DockerHostSetupStepWorker.jobs.last["args"]).to eq([ docker_host.id, step ])
        expect(response).to be_successful
        expect(response.body).to include("Running")
      end
    end

    it "rejects unknown steps without enqueuing" do
      expect {
        post :run_setup_step, params: { id: docker_host.id, step: "evil-step" }, format: :turbo_stream
      }.not_to change(DockerHostSetupStepWorker.jobs, :size)
      expect(response).to be_successful
      expect(response.body).to include("Unknown step")
    end
  end

  describe "#update" do
    let(:docker_host) { create(:docker_host, hostname: "de1.serveme.tf") }

    it "updates hostname and ip" do
      patch :update, params: { id: docker_host.id, docker_host: { hostname: "de2.serveme.tf", ip: "5.6.7.8" } }
      docker_host.reload
      expect(docker_host.hostname).to eq("de2.serveme.tf")
      expect(docker_host.ip).to eq("5.6.7.8")
      expect(response).to redirect_to(admin_docker_hosts_path)
    end
  end

  context "for non-admin users" do
    before { sign_in create(:user) }

    it "redirects to root" do
      get :index
      expect(response).to redirect_to(root_path)
    end
  end
end
