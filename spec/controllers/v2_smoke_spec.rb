# typed: false
# frozen_string_literal: true

require 'spec_helper'

# Smoke-renders the +v2 templates (beta variant) to catch runtime errors that the
# classic-template suite can't see. Not exhaustive — one representative GET per page.
describe "v2 template smoke render", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    u = create :user
    u.groups << Group.admin_group
    u.groups << Group.donator_group
    u.groups << Group.league_admin_group
    u
  end

  before do
    sign_in admin
    cookies[:ui_v2] = "true"
  end

  define_method(:expect_v2) do |path|
    get path
    follow_redirect! if response.status == 302
    expect(response).to have_http_status(:ok), "#{path} -> #{response.status}"
    expect(response.body).to include("/builds/v2.css"), "#{path} did not render the v2 layout"
  end

  it "pages" do
    expect_v2 faq_path
    expect_v2 credits_path
    expect_v2 server_providers_path
    expect_v2 private_server_info_path
    expect_v2 cloud_info_path
    expect_v2 statistics_path
  end

  it "players + statistics" do
    reservation = create :reservation
    server = reservation.server
    expect_v2 players_path
    expect_v2 player_statistics_path
    expect_v2 server_statistics_path
    # The show_for_* actions render the index template; ensure beta still kicks in.
    expect_v2 show_server_player_statistic_path(server_id: server)
    expect_v2 show_server_statistic_path(server_id: server)
  end

  it "sessions/login" do
    sign_out admin
    get new_session_path
    expect(response).to have_http_status(:ok)
  end

  it "donators / sdr / pings" do
    expect_v2 leaderboard_donators_path
    expect_v2 sdr_path
    expect_v2 pings_path
  end

  it "server_configs" do
    create :server_config
    expect_v2 server_configs_path
    expect_v2 new_server_config_path
  end

  it "servers" do
    create :server
    expect_v2 servers_path
    expect_v2 new_server_path
  end

  it "map_uploads" do
    # /maps redirects admins to /admin/maps (converted in a later wave); test the upload form here.
    expect_v2 new_map_upload_path
  end

  it "reservations" do
    res = create :reservation, user: admin
    expect_v2 reservations_path
    expect_v2 new_reservation_path
    expect_v2 your_reservations_path
    expect_v2 played_in_path
    expect_v2 reservation_path(res)
    expect_v2 edit_reservation_path(res)
    expect_v2 new_cloud_reservation_path
  end

  it "donations / vouchers / settings / uploads / league" do
    expect_v2 donate_path
    expect_v2 new_voucher_path
    expect_v2 settings_path
    expect_v2 new_file_upload_path
    expect_v2 league_request_path
  end

  it "admin: docker + cloud_image" do
    expect_v2 admin_docker_hosts_path
    expect_v2 new_admin_docker_host_path
    expect_v2 admin_cloud_image_builds_path
  end

  it "admin: products / vouchers / users / maps / scoreboards" do
    create :product
    expect_v2 admin_products_path
    expect_v2 new_admin_product_path
    expect_v2 admin_vouchers_path
    expect_v2 new_admin_voucher_path
    expect_v2 admin_users_path
    expect_v2 new_admin_user_path
    expect_v2 admin_user_path(admin)
    expect_v2 edit_admin_user_path(admin)
    expect_v2 admin_maps_path
    expect_v2 admin_scoreboards_path
  end

  it "admin: league_maps / notifications / site_settings" do
    expect_v2 admin_league_maps_path
    expect_v2 admin_server_notifications_path
    expect_v2 edit_admin_site_settings_path
  end

  it "monitoring / stac_logs / beta" do
    expect_v2 server_monitoring_path
    expect_v2 stac_logs_path
    expect_v2 beta_path
  end

  it "404 page renders v2" do
    get "/404"
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("/builds/v2.css")
    expect(response.body).to include("Page not found")
  end

  # Validation-failure re-renders: #create re-renders :new and #update re-renders
  # :edit, which have no +v2 of their own. They must still render in the v2 layout.
  it "re-renders :new in v2 on a failed create (conventional)" do
    post server_configs_path, params: { server_config: { file: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("/builds/v2.css"), "failed create did not render the v2 layout"
  end

  it "re-renders :index in v2 on a failed create (beta_renders_as :index)" do
    post admin_server_notifications_path, params: { server_notification: { message: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("/builds/v2.css"), "failed create did not render the v2 layout"
  end
end
