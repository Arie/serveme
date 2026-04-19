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
    let(:setup_service) { instance_double(DockerHostSetupService) }

    before do
      allow(DockerHostSetupService).to receive(:new).and_return(setup_service)
    end

    it "runs the dns step" do
      allow(setup_service).to receive(:check_dns).and_return({ success: true, message: "DNS record created" })

      post :run_setup_step, params: { id: docker_host.id, step: "dns" }, format: :turbo_stream
      expect(response).to be_successful
      expect(setup_service).to have_received(:check_dns)
    end

    it "runs the ssh step" do
      allow(setup_service).to receive(:check_ssh).and_return({ success: true, message: "SSH OK" })

      post :run_setup_step, params: { id: docker_host.id, step: "ssh" }, format: :turbo_stream
      expect(response).to be_successful
      expect(setup_service).to have_received(:check_ssh)
    end

    it "runs the provision step" do
      allow(setup_service).to receive(:provision_host).and_return({ success: true, message: "Provisioned" })

      post :run_setup_step, params: { id: docker_host.id, step: "provision" }, format: :turbo_stream
      expect(response).to be_successful
      expect(setup_service).to have_received(:provision_host)
    end

    it "runs the ssl step" do
      allow(setup_service).to receive(:check_ssl).and_return({ success: true, message: "SSL OK" })

      post :run_setup_step, params: { id: docker_host.id, step: "ssl" }, format: :turbo_stream
      expect(response).to be_successful
      expect(setup_service).to have_received(:check_ssl)
    end

    it "runs the pull_image step" do
      allow(setup_service).to receive(:pull_image).and_return({ success: true, message: "Image pulled" })

      post :run_setup_step, params: { id: docker_host.id, step: "pull_image" }, format: :turbo_stream
      expect(response).to be_successful
      expect(setup_service).to have_received(:pull_image)
    end

    it "rejects invalid steps" do
      post :run_setup_step, params: { id: docker_host.id, step: "invalid" }, format: :turbo_stream
      expect(response).to be_successful
      expect(setup_service).not_to have_received(:check_dns) if setup_service.respond_to?(:check_dns)
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
