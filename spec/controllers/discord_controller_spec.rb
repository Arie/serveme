# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe DiscordController, type: :controller do
  let(:token_url) { "https://discord.com/api/oauth2/token" }
  let(:user_url) { "https://discord.com/api/users/@me" }
  let(:connections_url) { "https://discord.com/api/users/@me/connections" }
  let(:state) { "abc123state" }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  around do |example|
    VCR.turned_off { example.run }
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    %w[eu na sea au].each do |region|
      allow(Rails.application.credentials).to receive(:dig)
        .with(:discord, :"#{region}_client_id").and_return("#{region}-client-id")
      allow(Rails.application.credentials).to receive(:dig)
        .with(:discord, :"#{region}_client_secret").and_return("#{region}-client-secret")
    end
  end

  describe "GET #invite" do
    before { sign_in create(:user) }

    it "redirects to the bot invite URL with the EU client id and permissions" do
      get :invite

      expect(response).to redirect_to(
        "https://discord.com/oauth2/authorize?client_id=eu-client-id&permissions=#{2048 + 16_384}&scope=bot"
      )
    end

    {
      "https://na.serveme.tf" => "na",
      "https://sea.serveme.tf" => "sea",
      "https://au.serveme.tf" => "au"
    }.each do |site_url, region|
      it "uses the #{region} client id when SITE_URL is #{site_url}" do
        stub_const("SITE_URL", site_url)

        get :invite

        expect(response.location).to include("client_id=#{region}-client-id")
      end
    end
  end

  describe "GET #link" do
    it "does not require login, stores a state in the cache and redirects to Discord OAuth" do
      allow(SecureRandom).to receive(:hex).with(16).and_return(state)

      get :link

      uri = URI.parse(response.location)
      query = Rack::Utils.parse_query(uri.query)
      expect(response).to have_http_status(:redirect)
      expect(uri.host).to eq("discord.com")
      expect(uri.path).to eq("/api/oauth2/authorize")
      expect(query).to eq(
        "client_id" => "eu-client-id",
        "redirect_uri" => "http://test.host/discord/callback",
        "response_type" => "code",
        "scope" => "identify connections",
        "state" => state
      )
      expect(Rails.cache.read("discord_link_state:#{state}")).to include(:created_at)
    end
  end

  describe "GET #callback" do
    let!(:user) { create(:user, uid: "76561197960497430", nickname: "Arie") }
    let(:discord_user) { { "id" => "555", "username" => "ariediscord" } }
    let(:connections) { [ { "type" => "twitch", "id" => "x" }, { "type" => "steam", "id" => "76561197960497430" } ] }

    before do
      Rails.cache.write("discord_link_state:#{state}", { created_at: Time.current })
    end

    let(:stub_token_success) do
      stub_request(:post, token_url)
        .to_return(status: 200, body: { access_token: "tok" }.to_json, headers: json_headers)
    end

    let(:stub_user_success) do
      stub_request(:get, user_url)
        .with(headers: { "Authorization" => "Bearer tok" })
        .to_return(status: 200, body: discord_user.to_json, headers: json_headers)
    end

    let(:stub_connections_success) do
      stub_request(:get, connections_url)
        .with(headers: { "Authorization" => "Bearer tok" })
        .to_return(status: 200, body: connections.to_json, headers: json_headers)
    end

    it "renders forbidden when Discord returns an error" do
      get :callback, params: { error: "access_denied", error_description: "User said no" }

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to eq("Authorization denied: User said no")
    end

    it "renders bad request when state is missing" do
      get :callback, params: { code: "c" }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq("Invalid or expired state. Please try again.")
    end

    it "renders bad request when state is unknown" do
      get :callback, params: { state: "unknown", code: "c" }

      expect(response).to have_http_status(:bad_request)
    end

    it "consumes the state and renders bad gateway when token exchange fails" do
      stub_request(:post, token_url).to_return(status: 401, body: "{}")

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.body).to eq("Failed to get access token from Discord.")
      expect(Rails.cache.read("discord_link_state:#{state}")).to be_nil
    end

    it "renders bad gateway and logs when the token request raises" do
      stub_request(:post, token_url).to_raise(SocketError.new("boom"))
      allow(Rails.logger).to receive(:error)

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:bad_gateway)
      expect(Rails.logger).to have_received(:error).with("Discord token exchange failed: boom")
    end

    it "renders bad gateway when fetching the Discord user fails" do
      stub_token_success
      stub_request(:get, user_url).to_return(status: 500, body: "")
      stub_connections_success

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:bad_gateway)
      expect(response.body).to eq("Failed to get Discord user info.")
    end

    it "renders bad gateway and logs when the Discord API request raises" do
      stub_token_success
      stub_request(:get, user_url).to_timeout
      stub_connections_success
      allow(Rails.logger).to receive(:error)

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:bad_gateway)
      expect(Rails.logger).to have_received(:error).with(/Discord API request failed/)
    end

    it "renders unprocessable entity when there is no Steam connection" do
      stub_token_success
      stub_user_success
      stub_request(:get, connections_url)
        .to_return(status: 200, body: [ { "type" => "twitch", "id" => "x" } ].to_json, headers: json_headers)

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("No Steam account linked to your Discord")
    end

    it "renders unprocessable entity when connections cannot be fetched" do
      stub_token_success
      stub_user_success
      stub_request(:get, connections_url).to_return(status: 403, body: "")

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renders not found when no user has the Steam ID" do
      stub_token_success
      stub_user_success
      stub_request(:get, connections_url)
        .to_return(status: 200, body: [ { "type" => "steam", "id" => "999" } ].to_json, headers: json_headers)

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("No serveme.tf account found for Steam ID 999")
    end

    it "renders conflict when the Discord account is linked to another user" do
      create(:user, uid: "111", nickname: "Other", discord_uid: "555")
      stub_token_success
      stub_user_success
      stub_connections_success

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:conflict)
      expect(response.body).to include("already linked to another serveme.tf user (Other)")
      expect(user.reload.discord_uid).to be_nil
    end

    it "links the Discord account and sends the expected token request" do
      token_stub = stub_request(:post, token_url)
        .with(body: {
          client_id: "eu-client-id",
          client_secret: "eu-client-secret",
          grant_type: "authorization_code",
          code: "the-code",
          redirect_uri: "http://test.host/discord/callback"
        })
        .to_return(status: 200, body: { access_token: "tok" }.to_json, headers: json_headers)
      stub_user_success
      stub_connections_success

      get :callback, params: { state: state, code: "the-code" }

      expect(token_stub).to have_been_requested
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(
        "Success! Your Discord account (ariediscord) is now linked to Arie on #{SITE_HOST}.\n\n" \
        "You can close this window and use /serveme in Discord."
      )
      expect(user.reload.discord_uid).to eq("555")
    end

    it "relinks when the Discord account is already linked to the same user" do
      user.update!(discord_uid: "555")
      stub_token_success
      stub_user_success
      stub_connections_success

      get :callback, params: { state: state, code: "c" }

      expect(response).to have_http_status(:ok)
      expect(user.reload.discord_uid).to eq("555")
    end

    it "mentions the regional command name outside the EU" do
      stub_const("SITE_URL", "https://na.serveme.tf")
      stub_token_success
      stub_user_success
      stub_connections_success

      get :callback, params: { state: state, code: "c" }

      expect(response.body).to include("use /serveme-na in Discord")
    end
  end
end
