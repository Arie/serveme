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
