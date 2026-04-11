# typed: false

require "spec_helper"

RSpec.describe CloudProvider::Base do
  subject(:provider) { described_class.new }

  describe "#cloud_init_script (private)" do
    let(:cloud_server) { create(:cloud_server, rcon: rcon_password) }

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
        expect(script).to include("-e RCON_PASSWORD=\\$\\(whoami\\)")
      end
    end
  end
end
