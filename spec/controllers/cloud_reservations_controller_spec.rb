# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudReservationsController do
  let(:user) { create(:user) }

  before do
    allow(user).to receive(:banned?).and_return(false)
  end

  describe "GET #new" do
    context "as admin" do
      before do
        user.groups << Group.admin_group
        sign_in user
      end

      it "renders the new template" do
        get :new

        expect(response).to be_successful
        expect(assigns(:reservation)).to be_a_new(Reservation)
        expect(assigns(:cloud_locations)).to eq(CloudProvider.grouped_locations)
      end
    end

    context "as regular user" do
      before { sign_in user }

      it "redirects to root" do
        get :new

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST #create" do
    before do
      user.groups << Group.admin_group
      sign_in user
    end

    let(:valid_params) do
      {
        cloud_location: "hetzner:fsn1",
        reservation: {
          password: "testpass",
          rcon: "testrcon",
          enable_plugins: "1",
          auto_end: "1",
          ends_at: 2.hours.from_now
        }
      }
    end

    it "creates a CloudServer and Reservation" do
      allow(CloudServerProvisionWorker).to receive(:perform_async)

      expect {
        post :create, params: valid_params
      }.to change(CloudServer, :count).by(1)
        .and change(Reservation, :count).by(1)

      cloud_server = CloudServer.last
      expect(cloud_server.cloud_provider).to eq("hetzner")
      expect(cloud_server.cloud_location).to eq("fsn1")
      expect(cloud_server.cloud_status).to eq("provisioning")

      reservation = Reservation.last
      expect(reservation.server).to eq(cloud_server)
      expect(reservation.user).to eq(user)
    end

    it "creates a CloudServer with Vultr provider" do
      allow(CloudServerProvisionWorker).to receive(:perform_async)

      expect {
        post :create, params: valid_params.merge(cloud_location: "vultr:fra")
      }.to change(CloudServer, :count).by(1)

      cloud_server = CloudServer.last
      expect(cloud_server.cloud_provider).to eq("vultr")
      expect(cloud_server.cloud_location).to eq("fra")
    end

    it "enqueues CloudServerProvisionWorker" do
      expect(CloudServerProvisionWorker).to receive(:perform_async)

      post :create, params: valid_params
    end

    it "redirects to the reservation" do
      allow(CloudServerProvisionWorker).to receive(:perform_async)

      post :create, params: valid_params

      expect(response).to redirect_to(reservation_path(Reservation.last))
    end

    it "sets flash notice about provisioning" do
      allow(CloudServerProvisionWorker).to receive(:perform_async)

      post :create, params: valid_params

      expect(flash[:notice]).to include("provisioned")
    end

    context "with invalid cloud location" do
      it "redirects with an error" do
        post :create, params: valid_params.merge(cloud_location: "bogus:location")

        expect(response).to redirect_to(new_cloud_reservation_path)
        expect(flash[:alert]).to eq("Invalid cloud location.")
      end
    end

    context "with invalid reservation params" do
      it "destroys the cloud server and re-renders the form" do
        invalid_params = valid_params.deep_merge(reservation: { password: "" })

        expect {
          post :create, params: invalid_params
        }.not_to change(CloudServer, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
