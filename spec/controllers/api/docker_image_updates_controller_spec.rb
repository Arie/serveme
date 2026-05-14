# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Api::DockerImageUpdatesController do
  describe "#create" do
    context "without authentication" do
      it "returns unauthorized" do
        post :create, format: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user" do
      let(:user) { create(:user) }

      before do
        allow(controller).to receive(:api_user).and_return(user)
      end

      it "returns forbidden" do
        post :create, format: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with admin user" do
      let(:admin) { create(:user, :admin) }

      before do
        allow(controller).to receive(:api_user).and_return(admin)
      end

      it "queues a pull worker" do
        expect(DockerHostImagePullWorker).to receive(:perform_async)

        post :create, format: :json

        expect(response).to have_http_status(:ok)
      end

      it "records the propagated TF2 image version in SiteSetting" do
        allow(DockerHostImagePullWorker).to receive(:perform_async)

        post :create, params: { version: "9876543" }, format: :json

        expect(SiteSetting.get(DockerImageReadiness::VERSION_SETTING_KEY)).to eq("9876543")
      end
    end
  end
end
