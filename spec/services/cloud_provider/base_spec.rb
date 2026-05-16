# typed: false

require "spec_helper"

RSpec.describe CloudProvider::Base do
  subject(:provider) { described_class.new }

  describe "#cloud_init_script (private)" do
    let(:cloud_server) { create(:cloud_server, rcon: rcon_password, cloud_callback_token: "vm-callback-token") }

    before do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig)
        .with(:cloud_servers, :ssh_public_key)
        .and_return("ssh-ed25519 AAAA test@serveme")
    end

    context "when RCON password contains shell metacharacters" do
      let(:rcon_password) { '$(whoami)' }

      it "shell-escapes the RCON password" do
        script = provider.send(:cloud_init_script, cloud_server)

        expect(script).not_to include("-e RCON_PASSWORD=$(whoami)")
        expect(script).to match(/-e RCON_PASSWORD=(?:\\\$\\\(whoami\\\)|'\$\(whoami\)')/)
      end
    end

    context "seccomp profile" do
      let(:rcon_password) { "rcon" }

      it "writes the custom seccomp profile and applies it to docker run" do
        script = provider.send(:cloud_init_script, cloud_server)

        expect(script).to include("/etc/docker/seccomp-tf2.json")
        expect(script).to match(%r{--security-opt seccomp=/etc/docker/seccomp-tf2\.json})
      end
    end

    context "VM-mode container env contract" do
      let(:rcon_password) { "rcon" }

      it "emits CALLBACK/SSH/RCON/SSH_PORT=2222/ENABLE_FAKEIP/EXPECTED_TF2_VERSION and no per-game ports" do
        allow(Server).to receive(:latest_version).and_return("9876543")
        script = provider.send(:cloud_init_script, cloud_server)

        aggregate_failures do
          expect(script).to match(%r{-e CALLBACK_URL=https://#{Regexp.escape(SITE_HOST)}/api/cloud_servers/#{cloud_server.id}/ready})
          expect(script).to match(/-e CALLBACK_TOKEN=vm-callback-token\b/)
          expect(script).to match(/-e SSH_AUTHORIZED_KEYS=(?:"ssh-ed25519 AAAA test@serveme"|ssh-ed25519\\ AAAA\\ test@serveme|'ssh-ed25519 AAAA test@serveme')/)
          expect(script).to match(/-e SSH_PORT=2222\b/)
          expect(script).to match(/-e ENABLE_FAKEIP=1\b/)
          expect(script).to match(/-e EXPECTED_TF2_VERSION=9876543\b/)
          %w[PORT TV_PORT CLIENT_PORT STEAM_PORT].each do |var|
            expect(script).not_to match(/-e #{var}=/)
          end
        end
      end
    end

    context "DISCORD_STAC_WEBHOOK_URL" do
      let(:rcon_password) { "rcon" }

      before { allow(ENV).to receive(:[]).and_call_original }

      it "uses the ENV var when set" do
        allow(ENV).to receive(:[]).with("DISCORD_STAC_WEBHOOK_URL")
          .and_return("https://discord.com/api/webhooks/vm/from-env")

        script = provider.send(:cloud_init_script, cloud_server)
        expect(script).to match(%r{-e DISCORD_STAC_WEBHOOK_URL=https://discord\.com/api/webhooks/vm/from-env})
      end

      it "falls back to the discord.stac_webhook_url credential when ENV is unset" do
        allow(ENV).to receive(:[]).with("DISCORD_STAC_WEBHOOK_URL").and_return(nil)
        allow(Rails.application.credentials).to receive(:dig)
          .with(:discord, :stac_webhook_url)
          .and_return("https://discord.com/api/webhooks/vm/from-cred")

        script = provider.send(:cloud_init_script, cloud_server)
        expect(script).to match(%r{-e DISCORD_STAC_WEBHOOK_URL=https://discord\.com/api/webhooks/vm/from-cred})
      end

      it "omits the flag when neither source is set" do
        allow(ENV).to receive(:[]).with("DISCORD_STAC_WEBHOOK_URL").and_return(nil)
        allow(Rails.application.credentials).to receive(:dig)
          .with(:discord, :stac_webhook_url).and_return(nil)

        script = provider.send(:cloud_init_script, cloud_server)
        expect(script).not_to match(/DISCORD_STAC_WEBHOOK_URL/)
      end
    end
  end
end
