# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::SearchAltsTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("search_alts")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires league_admin role" do
      expect(described_class.required_role).to eq(:league_admin)
    end

    it "has an input schema with steam_uid and ip properties" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:steam_uid)
      expect(schema[:properties]).to have_key(:ip)
      expect(schema[:properties]).to have_key(:cross_reference)
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }

    let(:suspect_uid) { "76561198012345678" }
    let(:suspect_ip) { "192.168.1.100" }
    let!(:reservation) { create(:reservation) }
    let!(:reservation_player) do
      create(:reservation_player,
        reservation: reservation,
        steam_uid: suspect_uid,
        ip: suspect_ip,
        name: "SuspectPlayer"
      )
    end

    context "with steam_uid parameter" do
      it "returns aggregated results for the steam_uid" do
        result = tool.execute(steam_uid: suspect_uid)

        expect(result[:accounts]).to be_an(Array)
        expect(result[:target]).to include(suspect_uid)
        expect(result[:accounts].first).to include(
          steam_uid: suspect_uid,
          name: "SuspectPlayer",
          ip: suspect_ip,
          reservation_count: 1
        )
        expect(result[:accounts].first).to have_key(:first_seen)
        expect(result[:accounts].first).to have_key(:last_seen)
        expect(result[:accounts].first).to have_key(:all_names)
        expect(result[:accounts].first).to have_key(:all_ips)
      end
    end

    context "with ip parameter" do
      it "returns aggregated results for the ip" do
        result = tool.execute(ip: suspect_ip)

        expect(result[:accounts]).to be_an(Array)
        expect(result[:target]).to include(suspect_ip)
        expect(result[:accounts].first).to include(
          steam_uid: suspect_uid,
          reservation_count: 1
        )
      end
    end

    context "with cross_reference enabled" do
      let(:other_ip) { "192.168.1.200" }
      let!(:other_player) do
        create(:reservation_player,
          reservation: reservation,
          steam_uid: suspect_uid,
          ip: other_ip,
          name: "SamePlayerOtherIP"
        )
      end

      it "returns cross-referenced results with all IPs and names" do
        result = tool.execute(steam_uid: suspect_uid, cross_reference: true)

        expect(result[:accounts]).to be_an(Array)
        account = result[:accounts].find { |r| r[:steam_uid] == suspect_uid }
        expect(account).to be_present
        expect(account[:all_ips]).to include(suspect_ip, other_ip)
        expect(account[:all_names]).to include("SuspectPlayer", "SamePlayerOtherIP")
      end
    end

    context "with multiple reservations for the same player" do
      let!(:second_reservation) { create(:reservation) }
      let!(:second_player) do
        create(:reservation_player,
          reservation: second_reservation,
          steam_uid: suspect_uid,
          ip: suspect_ip,
          name: "SuspectPlayerRenamed"
        )
      end

      it "aggregates into a single result with reservation_count" do
        result = tool.execute(steam_uid: suspect_uid, cross_reference: false)

        expect(result[:accounts].size).to eq(1)
        account = result[:accounts].first
        expect(account[:steam_uid]).to eq(suspect_uid)
        expect(account[:reservation_count]).to eq(2)
        expect(account[:all_names]).to include("SuspectPlayer", "SuspectPlayerRenamed")
      end
    end

    context "with no parameters" do
      it "returns empty results" do
        result = tool.execute({})

        expect(result[:accounts]).to eq([])
        expect(result[:error]).to include("parameter")
      end
    end

    context "banned status" do
      let(:banned_uid) { "76561198999999999" }
      let(:ban_reason) { "cheating" }
      let!(:banned_player) do
        create(:reservation_player,
          reservation: reservation,
          steam_uid: banned_uid,
          ip: suspect_ip,
          name: "BannedPlayer"
        )
      end

      before do
        allow(ReservationPlayer).to receive(:banned_uids).and_return({ banned_uid.to_i => ban_reason })
      end

      it "includes banned status and ban_reason for banned accounts" do
        result = tool.execute(ip: suspect_ip)

        banned_account = result[:accounts].find { |a| a[:steam_uid] == banned_uid }
        expect(banned_account[:banned]).to be true
        expect(banned_account[:ban_reason]).to eq(ban_reason)
      end

      it "includes banned: false for non-banned accounts" do
        result = tool.execute(ip: suspect_ip)

        clean_account = result[:accounts].find { |a| a[:steam_uid] == suspect_uid }
        expect(clean_account[:banned]).to be false
        expect(clean_account[:ban_reason]).to be_nil
      end
    end

    context "with first_seen_after filter" do
      let(:old_reservation) { create(:reservation) }
      let(:new_reservation) { create(:reservation) }
      let(:old_uid) { "76561198111111111" }
      let(:new_uid) { "76561198222222222" }
      let(:shared_ip) { "10.0.0.1" }

      let!(:old_player) do
        old_reservation.update_column(:starts_at, 1.year.ago)
        create(:reservation_player,
          reservation: old_reservation,
          steam_uid: old_uid,
          ip: shared_ip,
          name: "OldPlayer"
        )
      end

      let!(:new_player) do
        new_reservation.update_column(:starts_at, 1.day.ago)
        create(:reservation_player,
          reservation: new_reservation,
          steam_uid: new_uid,
          ip: shared_ip,
          name: "NewPlayer"
        )
      end

      it "only returns accounts first seen after the given date" do
        result = tool.execute(ip: shared_ip, first_seen_after: 1.month.ago.to_date.iso8601)

        uids = result[:accounts].map { |a| a[:steam_uid] }
        expect(uids).to include(new_uid)
        expect(uids).not_to include(old_uid)
      end

      it "returns all accounts when first_seen_after is not specified" do
        result = tool.execute(ip: shared_ip)

        uids = result[:accounts].map { |a| a[:steam_uid] }
        expect(uids).to include(old_uid, new_uid)
      end
    end
  end
end
