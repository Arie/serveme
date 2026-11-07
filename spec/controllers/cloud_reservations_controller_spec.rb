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
        expect(assigns(:cloud_locations)).to eq(CloudProvider.grouped_locations(user: user))
      end
    end

    context "as donator" do
      before do
        user.groups << Group.donator_group
        sign_in user
      end

      it "renders the new template" do
        get :new

        expect(response).to be_successful
        expect(assigns(:reservation)).to be_a_new(Reservation)
      end
    end

    context "as regular user" do
      before do
        sign_in user
      end

      it "redirects to root" do
        get :new

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Cloud servers are available to Premium users.")
      end
    end
  end

  describe "GET #available_locations" do
    before do
      user.groups << Group.admin_group
      sign_in user
    end

    it "returns locations for the requested window" do
      starts_at = 1.day.from_now.change(usec: 0)
      ends_at = starts_at + 2.hours
      expect(CloudProvider).to receive(:grouped_locations)
        .with(starts_at: starts_at, ends_at: ends_at, user: user).and_return("Germany" => [ [ "Falkenstein (Hetzner)", "hetzner:fsn1" ] ])

      get :available_locations, params: { starts_at: starts_at.iso8601, ends_at: ends_at.iso8601 }

      expect(JSON.parse(response.body)).to eq("Germany" => [ [ "Falkenstein (Hetzner)", "hetzner:fsn1" ] ])
    end
  end

  describe "POST #create" do
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

    context "as admin" do
      before do
        user.groups << Group.admin_group
        sign_in user
      end

      it "enqueues CloudServerProvisionWorker" do
        expect(CloudServerProvisionWorker).to receive(:perform_async)

        post :create, params: valid_params
        expect(response).to redirect_to(reservation_path(Reservation.last))
        expect(flash[:notice]).to include("provisioned")
      end

      context "with invalid cloud location" do
        it "redirects with an error" do
          post :create, params: valid_params.merge(cloud_location: "bogus:location")

          expect(response).to redirect_to(new_cloud_reservation_path)
          expect(flash[:alert]).to eq("Invalid cloud location.")
        end

        it "refuses the dev-only local docker provider outside development" do
          expect {
            post :create, params: valid_params.merge(cloud_location: "docker:local")
          }.not_to change(CloudServer, :count)

          expect(flash[:alert]).to eq("Invalid cloud location.")
        end

        it "refuses an inactive docker host" do
          host = create(:docker_host, active: false)

          expect {
            post :create, params: valid_params.merge(cloud_location: "remote_docker:#{host.id}")
          }.not_to change(CloudServer, :count)

          expect(flash[:alert]).to eq("Invalid cloud location.")
        end

        it "refuses a location outside the site's region" do
          other_region = CloudProvider::Hetzner.locations.find { |_code, info| info[:region] != CloudProvider::SITE_REGION }&.first
          skip "no other-region Hetzner location" unless other_region

          post :create, params: valid_params.merge(cloud_location: "hetzner:#{other_region}")

          expect(flash[:alert]).to eq("Invalid cloud location.")
        end
      end

      it "destroys the cloud server when the reservation is invalid" do
        expect(CloudServerProvisionWorker).not_to receive(:perform_async)

        expect {
          post :create, params: valid_params.deep_merge(reservation: { ends_at: 1.hour.ago })
        }.not_to change(CloudServer, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:new)
      end

      it "asks to retry when the lock is busy" do
        allow($lock).to receive(:synchronize).and_raise(RemoteLock::Error)

        expect {
          post :create, params: valid_params
        }.not_to change(CloudServer, :count)

        expect(response).to redirect_to(new_cloud_reservation_path)
        expect(flash[:alert]).to eq("Server is busy, please try again.")
      end

      it "refuses a docker host that filled up after the form was offered" do
        host = create(:docker_host)
        allow(controller).to receive(:offered_location?).and_return(true)
        allow_any_instance_of(DockerHost).to receive(:full_during?).and_return(true)

        expect {
          post :create, params: valid_params.merge(cloud_location: "remote_docker:#{host.id}")
        }.not_to change(CloudServer, :count)

        expect(response).to redirect_to(new_cloud_reservation_path)
        expect(flash[:alert]).to include("full capacity")
      end

      context "with an active cloud server" do
        let!(:active) { create(:reservation, user: user, server: create(:cloud_server)) }

        it "redirects to the active reservation" do
          expect {
            post :create, params: valid_params
          }.not_to change(CloudServer, :count)

          expect(response).to redirect_to(reservation_path(active))
          expect(flash[:alert]).to include("already have an active cloud server")
        end

        it "still allows a docker host" do
          host = create(:docker_host)

          expect {
            post :create, params: valid_params.merge(cloud_location: "remote_docker:#{host.id}")
                                              .deep_merge(reservation: { starts_at: 3.hours.from_now, ends_at: 5.hours.from_now })
          }.to change(CloudServer, :count).by(1)
        end
      end

      context "with a future starts_at" do
        it "does not provision immediately when starts_at is more than 5 minutes away" do
          future_time = 1.hour.from_now
          expect(CloudServerProvisionWorker).not_to receive(:perform_async)

          post :create, params: valid_params.deep_merge(
            reservation: { starts_at: future_time.iso8601 }
          )

          expect(response).to redirect_to(reservation_path(Reservation.last))
          expect(flash[:notice]).to include("scheduled")
        end

        it "uses perform_async when starts_at is less than 5 minutes away" do
          near_future = 3.minutes.from_now
          expect(CloudServerProvisionWorker).to receive(:perform_async)

          post :create, params: valid_params.deep_merge(
            reservation: { starts_at: near_future.iso8601 }
          )

          expect(response).to redirect_to(reservation_path(Reservation.last))
          expect(flash[:notice]).to include("provisioned")
        end

        it "uses perform_async when starts_at is in the past" do
          past_time = 5.minutes.ago
          expect(CloudServerProvisionWorker).to receive(:perform_async)

          post :create, params: valid_params.deep_merge(
            reservation: { starts_at: past_time.iso8601 }
          )

          expect(response).to redirect_to(reservation_path(Reservation.last))
        end
      end
    end
  end
end
