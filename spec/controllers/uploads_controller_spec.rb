# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe UploadsController do
  render_views false

  let(:owner) { create(:user) }
  let(:reservation) { create(:reservation, user: owner) }
  let(:tmp_dir) { Dir.mktmpdir }
  let(:zip_path) { Pathname.new(File.join(tmp_dir, "test.zip")) }

  before do
    File.write(zip_path, "zip contents")
    allow_any_instance_of(Reservation).to receive(:local_zipfile_path).and_return(zip_path)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  define_method(:download) do |res = reservation|
    get :show, params: { id: res.zipfile_name.delete_suffix(".zip") }
  end

  it "serves the zip to the user who made the reservation" do
    sign_in owner

    download

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("zip contents")
    expect(response.headers["Content-Type"]).to eq("application/zip")
    expect(response.headers["Content-Disposition"]).to include("attachment", reservation.zipfile_name)
  end

  it "serves the zip to a player of the ended reservation" do
    player = create(:user)
    reservation.update_columns(ended: true)
    create(:reservation_player, reservation: reservation, user: player, steam_uid: player.uid)
    sign_in player

    download

    expect(response).to have_http_status(:ok)
  end

  it "does not serve the zip to players while the reservation is still running" do
    player = create(:user)
    create(:reservation_player, reservation: reservation, user: player, steam_uid: player.uid)
    sign_in player

    download

    expect(response).to have_http_status(:not_found)
  end

  %i[admin_group league_admin_group streamer_group].each do |group|
    it "serves any reservation's zip to members of the #{group}" do
      privileged = create(:user, groups: [ Group.public_send(group) ])
      sign_in privileged

      download

      expect(response).to have_http_status(:ok)
    end
  end

  it "returns not found for privileged users requesting a non-existent reservation" do
    sign_in create(:admin)

    get :show, params: { id: "#{owner.uid}-0-1-20260101" }

    expect(response).to have_http_status(:not_found)
  end

  it "does not serve the zip to unrelated users" do
    sign_in create(:user)

    download

    expect(response).to have_http_status(:not_found)
  end

  it "sends anonymous visitors to log in" do
    download

    expect(response).to have_http_status(:redirect)
  end

  it "returns not found when the id cannot be parsed" do
    sign_in owner

    get :show, params: { id: "garbage" }

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found when the local zip is gone" do
    FileUtils.rm_f(zip_path)
    sign_in owner

    download

    expect(response).to have_http_status(:not_found)
  end
end
