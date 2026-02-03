# typed: false
# frozen_string_literal: true

require "spec_helper"

describe Api::IpLookupsController do
  render_views

  describe "#create" do
    context "without authentication" do
      it "returns unauthorized" do
        post :create, format: :json, params: { ip_lookup: { ip: "1.2.3.4" } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user" do
      let(:user) { create(:user) }

      before do
        allow(controller).to receive(:api_user).and_return(user)
      end

      it "returns forbidden" do
        post :create, format: :json, params: { ip_lookup: { ip: "1.2.3.4" } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with admin user" do
      let(:admin) { create(:user, :admin) }

      before do
        allow(controller).to receive(:api_user).and_return(admin)
      end

      it "creates a new IpLookup record" do
        expect {
          post :create, format: :json, params: {
            ip_lookup: {
              ip: "1.2.3.4",
              is_proxy: true,
              is_residential_proxy: true,
              fraud_score: 100,
              isp: "Test ISP",
              country_code: "US"
            }
          }
        }.to change(IpLookup, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["ip_lookup"]["ip"]).to eq("1.2.3.4")

        lookup = IpLookup.find_by(ip: "1.2.3.4")
        expect(lookup.is_proxy).to be true
        expect(lookup.is_residential_proxy).to be true
        expect(lookup.fraud_score).to eq(100)
        expect(lookup.isp).to eq("Test ISP")
        expect(lookup.country_code).to eq("US")
      end

      it "updates an existing IpLookup record" do
        existing = IpLookup.create!(ip: "2.2.2.2", fraud_score: 50, isp: "Old ISP")

        expect {
          post :create, format: :json, params: {
            ip_lookup: {
              ip: "2.2.2.2",
              fraud_score: 100,
              isp: "New ISP"
            }
          }
        }.not_to change(IpLookup, :count)

        expect(response).to have_http_status(:created)
        existing.reload
        expect(existing.fraud_score).to eq(100)
        expect(existing.isp).to eq("New ISP")
      end

      it "does not trigger re-sync (prevents loop)" do
        expect(IpLookupSyncWorker).not_to receive(:perform_async)

        post :create, format: :json, params: {
          ip_lookup: {
            ip: "3.3.3.3",
            fraud_score: 75
          }
        }

        expect(response).to have_http_status(:created)
      end

      it "returns unprocessable_entity for invalid data" do
        post :create, format: :json, params: {
          ip_lookup: {
            ip: nil
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
      end

      it "handles raw_response hash" do
        post :create, format: :json, params: {
          ip_lookup: {
            ip: "4.4.4.4",
            raw_response: { "provider" => "test", "region" => "US" }
          }
        }

        expect(response).to have_http_status(:created)
        lookup = IpLookup.find_by(ip: "4.4.4.4")
        expect(lookup.raw_response["provider"]).to eq("test")
        expect(lookup.raw_response["region"]).to eq("US")
      end
    end

    context "with league admin user" do
      let(:league_admin) do
        user = create(:user)
        user.groups << Group.league_admin_group
        user
      end

      before do
        allow(controller).to receive(:api_user).and_return(league_admin)
      end

      it "returns forbidden (admin only)" do
        post :create, format: :json, params: { ip_lookup: { ip: "1.2.3.4" } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
