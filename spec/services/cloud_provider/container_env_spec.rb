# typed: false

require "spec_helper"

RSpec.describe CloudProvider::ContainerEnv do
  let(:reservation) { create(:reservation, enable_plugins: true) }
  let(:cloud_server) { create(:cloud_server, cloud_reservation_id: reservation.id) }

  define_method(:env) do |mode: :multi|
    described_class.build(cloud_server, ssh_public_key: "ssh-ed25519 AAAA test@serveme", mode: mode)
  end

  describe "ENABLE_PLUGINS" do
    it "is 1 when the reservation wants plugins" do
      expect(env["ENABLE_PLUGINS"]).to eq("1")
    end

    it "is 0 when the reservation has plugins disabled" do
      reservation.update_columns(enable_plugins: false, enable_demos_tf: false)

      expect(env["ENABLE_PLUGINS"]).to eq("0")
    end

    it "is 1 when demos.tf is on even though plugins are off" do
      reservation.update_columns(enable_plugins: false, enable_demos_tf: true)

      expect(env["ENABLE_PLUGINS"]).to eq("1")
    end

    it "is 1 when the site setting forces plugins on" do
      reservation.update_columns(enable_plugins: false, enable_demos_tf: false)
      allow(SiteSetting).to receive(:always_enable_plugins?).and_return(true)

      expect(env["ENABLE_PLUGINS"]).to eq("1")
    end

    it "is emitted in VM mode too" do
      reservation.update_columns(enable_plugins: false, enable_demos_tf: false)

      expect(env(mode: :vm)["ENABLE_PLUGINS"]).to eq("0")
    end

    it "is left out when the server has no reservation" do
      cloud_server.update_column(:cloud_reservation_id, nil)

      expect(env).not_to have_key("ENABLE_PLUGINS")
    end
  end

  describe "ENABLE_DEMOS_TF" do
    it "is 1 when the reservation wants demos.tf" do
      reservation.update_columns(enable_plugins: true, enable_demos_tf: true)

      expect(env["ENABLE_DEMOS_TF"]).to eq("1")
    end

    it "is 0 when the reservation has demos.tf disabled" do
      expect(env["ENABLE_DEMOS_TF"]).to eq("0")
    end

    it "is 1 when the site setting forces demos.tf on" do
      allow(SiteSetting).to receive(:always_enable_demos_tf?).and_return(true)

      expect(env["ENABLE_DEMOS_TF"]).to eq("1")
    end

    it "is emitted in VM mode too" do
      expect(env(mode: :vm)["ENABLE_DEMOS_TF"]).to eq("0")
    end

    it "is left out when the server has no reservation" do
      cloud_server.update_column(:cloud_reservation_id, nil)

      expect(env).not_to have_key("ENABLE_DEMOS_TF")
    end
  end
end
