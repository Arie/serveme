# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::LeagueMapsController, type: :controller do
  let(:admin_user) { create(:user, :admin) }
  let(:config_admin_user) { create(:user, :config_admin) }
  let(:league_admin_user) do
    user = create(:user)
    user.groups << Group.league_admin_group
    user
  end
  let(:regular_user) { create(:user) }
  let(:streamer_user) do
    user = create(:user)
    user.groups << Group.streamer_group
    user
  end

  let(:mock_config) do
    {
      "league_maps" => [
        {
          "name" => "Test League",
          "active" => true,
          "maps" => [ "cp_test", "koth_test" ]
        }
      ]
    }
  end

  describe "GET #index" do
    context "as admin user" do
      before { sign_in admin_user }

      it "renders the index page" do
        allow(Rails.cache).to receive(:read).with(LeagueMapsSyncService::CACHE_KEY)
          .and_return(mock_config)
        allow_any_instance_of(LeagueMapsSyncService).to receive(:last_sync_time)
          .and_return(1.hour.ago)

        get :index
        expect(response).to have_http_status(:ok)
        expect(assigns(:current_config)).to eq(mock_config)
        expect(assigns(:league_maps)).not_to be_empty
      end
    end

    context "as config admin user" do
      before { sign_in config_admin_user }

      it "allows access to config admin" do
        allow(Rails.cache).to receive(:read).with(LeagueMapsSyncService::CACHE_KEY)
          .and_return(mock_config)
        allow(Rails.cache).to receive(:read).with("#{LeagueMapsSyncService::CACHE_KEY}_last_sync")
          .and_return(1.hour.ago)

        get :index
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST #fetch" do
    before { sign_in admin_user }

    it "fetches config from GitHub and shows preview" do
      service = instance_double(LeagueMapsSyncService)
      allow(LeagueMapsSyncService).to receive(:new).and_return(service)

      allow(service).to receive(:fetch_from_github).and_return(mock_config)
      allow(service).to receive(:validate_config).and_return({
        valid: true, errors: [], warnings: []
      })
      allow(service).to receive(:current_config).and_return({})
      allow(service).to receive(:generate_diff).and_return({
        added_leagues: [], removed_leagues: [], modified_leagues: []
      })

      post :fetch
      expect(response).to render_template(:preview)
      expect(assigns(:new_config)).to eq(mock_config)
    end

    it "redirects with error when fetch fails" do
      service = instance_double(LeagueMapsSyncService)
      allow(LeagueMapsSyncService).to receive(:new).and_return(service)
      allow(service).to receive(:fetch_from_github).and_return({})

      post :fetch
      expect(response).to redirect_to(admin_league_maps_path)
      expect(flash[:error]).to include("Failed to fetch")
    end
  end

  describe "POST #apply" do
    before { sign_in admin_user }

    it "applies valid configuration" do
      service = instance_double(LeagueMapsSyncService)
      allow(LeagueMapsSyncService).to receive(:new).and_return(service)

      allow(service).to receive(:validate_config).and_return({
        valid: true, errors: [], warnings: []
      })
      allow(service).to receive(:apply_config).and_return(true)

      post :apply, params: { config: mock_config.to_json }

      expect(response).to redirect_to(admin_league_maps_path)
      expect(flash[:success]).to include("updated successfully")
    end

    it "rejects invalid configuration" do
      service = instance_double(LeagueMapsSyncService)
      allow(LeagueMapsSyncService).to receive(:new).and_return(service)

      allow(service).to receive(:validate_config).and_return({
        valid: false, errors: [ "Invalid config" ], warnings: []
      })

      post :apply, params: { config: mock_config.to_json }

      expect(response).to redirect_to(admin_league_maps_path)
      expect(flash[:error]).to include("validation failed")
    end

    it "handles missing config parameter" do
      post :apply, params: {}

      expect(response).to redirect_to(admin_league_maps_path)
      expect(flash[:error]).to include("No configuration data provided")
    end

    it "handles JSON parse errors" do
      post :apply, params: { config: "invalid json" }

      expect(response).to redirect_to(admin_league_maps_path)
      expect(flash[:error]).to include("Invalid configuration data")
    end
  end

  describe "POST #force_sync" do
    before { sign_in admin_user }

    it "performs sync and shows success message" do
      allow(LeagueMapsSyncService).to receive(:fetch_and_apply).and_return(true)

      post :force_sync

      expect(response).to redirect_to(admin_league_maps_path)
      expect(flash[:success]).to include("synced successfully")
    end

    it "shows error message when sync fails" do
      allow(LeagueMapsSyncService).to receive(:fetch_and_apply).and_return(false)

      post :force_sync

      expect(response).to redirect_to(admin_league_maps_path)
      expect(flash[:error]).to include("Failed to sync")
    end
  end
end
