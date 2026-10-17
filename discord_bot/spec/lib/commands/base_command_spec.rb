# typed: false
# frozen_string_literal: true

require_relative "../../spec_helper"
require_relative "../../../lib/commands/base_command"

RSpec.describe ServemeBot::Commands::BaseCommand do
  let(:discord_user) { double(id: 123_456_789, username: "player") }
  let(:event) { double(user: discord_user, respond: nil) }
  let(:command) { described_class.new(event) }

  describe "#require_linked_account!" do
    it "allows a linked user" do
      create(:user, discord_uid: "123456789")

      expect(command.require_linked_account!).to be true
    end

    it "refuses a banned user, like the website does" do
      user = create(:user, discord_uid: "123456789")
      allow_any_instance_of(User).to receive(:banned?).and_return(true)
      allow_any_instance_of(User).to receive(:ban_reason).and_return("cheating")

      expect(command.require_linked_account!).to be false
      expect(event).to have_received(:respond).with(hash_including(content: /banned: cheating/, ephemeral: true))
      expect(user).to be_persisted
    end
  end
end
