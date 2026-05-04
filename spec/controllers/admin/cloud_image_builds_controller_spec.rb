# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Admin::CloudImageBuildsController do
  render_views

  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  before do
    stub_const("SITE_HOST", "serveme.tf")
    allow(DockerImageRegistryClient).to receive(:new).and_return(instance_double(DockerImageRegistryClient, fetch_digest: "sha256:remote"))
    SiteSetting.set(DockerImagePollWorker::DIGEST_SETTING_KEY, "sha256:local")
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  describe "GET #index" do
    context "as admin on EU" do
      before { sign_in admin_user }

      it "renders successfully" do
        create(:cloud_image_build, version: "1234")
        get :index
        expect(response).to be_successful
        expect(response.body).to include("Cloud Image Builds")
      end

      it "lists recent builds" do
        create(:cloud_image_build, version: "BUILDABC", status: "succeeded")
        get :index
        expect(response.body).to include("BUILDABC")
      end

      it "shows local and remote digest" do
        get :index
        # View strips "sha256:" prefix and truncates; for our test stubs ("sha256:local", "sha256:remote"), result is "local" and "remote"
        expect(response.body).to include("local").and include("remote")
      end

      it "shows the build trigger button when no build is in progress" do
        get :index
        expect(response.body).to include("Build New Image")
      end

      it "disables trigger and shows in-progress notice when a build is running" do
        running = create(:cloud_image_build, status: "running", version: "RUNNINGABC")
        get :index
        expect(response.body).to match(/already (running|in progress)/i)
        expect(response.body).to include(admin_cloud_image_build_path(running))
      end

      it "shows the pull-now button" do
        get :index
        expect(response.body).to include("Pull on all hosts")
      end
    end

    context "as non-admin" do
      before { sign_in regular_user }

      it "redirects to root" do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end

    context "on non-EU region" do
      before do
        sign_in admin_user
        stub_const("SITE_HOST", "na.serveme.tf")
      end

      it "redirects to root with alert" do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("EU region")
      end
    end
  end

  describe "GET #show" do
    before { sign_in admin_user }

    it "renders the build's status and output" do
      build = create(:cloud_image_build, version: "SHOWME", status: "succeeded", output: "the build log")
      get :show, params: { id: build.id }
      expect(response).to be_successful
      expect(response.body).to include("SHOWME")
      expect(response.body).to include("the build log")
      expect(response.body).to include("succeeded")
    end

    it "subscribes to the build's turbo streams" do
      build = create(:cloud_image_build, version: "STREAMME")
      get :show, params: { id: build.id }
      # signed_stream_name is opaque; just verify a turbo-cable-stream-source is rendered
      expect(response.body).to include("turbo-cable-stream-source")
    end
  end

  describe "POST #create" do
    before do
      sign_in admin_user
      allow(Server).to receive(:latest_version).and_return("9999999")
    end

    it "creates a build and enqueues the worker, then redirects to show" do
      expect(CloudImageBuildWorker).to receive(:perform_async).with(kind_of(Integer))

      expect { post :create }.to change(CloudImageBuild, :count).by(1)

      build = CloudImageBuild.last
      expect(build.version).to eq("9999999")
      expect(build.force_pull).to eq(false)
      expect(build.triggered_by_user).to eq(admin_user)
      expect(response).to redirect_to(admin_cloud_image_build_path(build))
    end

    it "honors force_pull param" do
      allow(CloudImageBuildWorker).to receive(:perform_async)
      post :create, params: { force_pull: "1" }
      expect(CloudImageBuild.last.force_pull).to eq(true)
    end

    it "redirects with alert if version cannot be fetched" do
      allow(Server).to receive(:latest_version).and_return(nil)
      expect(CloudImageBuildWorker).not_to receive(:perform_async)

      post :create

      expect(response).to redirect_to(admin_cloud_image_builds_path)
      expect(flash[:alert]).to include("Steam")
    end
  end

  describe "POST #pull_now" do
    before { sign_in admin_user }

    it "enqueues DockerHostImagePullWorker and redirects to index" do
      expect(DockerHostImagePullWorker).to receive(:perform_async)

      post :pull_now

      expect(response).to redirect_to(admin_cloud_image_builds_path)
      expect(flash[:notice]).to be_present
    end
  end
end
