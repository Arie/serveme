# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe UserSearchService do
  let!(:user) { create(:user, uid: "76561197960287930", nickname: "TestPlayer") }

  describe "#search" do
    context "with blank input" do
      it "returns empty array" do
        service = described_class.new("")
        expect(service.search).to eq([])
      end

      it "returns empty array for nil input" do
        service = described_class.new(nil)
        expect(service.search).to eq([])
      end
    end

    context "with user ID" do
      it "finds user by ID with # prefix" do
        service = described_class.new("##{user.id}")
        expect(service.search).to eq([ user ])
      end

      it "finds user by ID without # prefix" do
        service = described_class.new(user.id.to_s)
        expect(service.search).to eq([ user ])
      end
    end

    context "with Steam ID64" do
      it "finds user by Steam ID64" do
        service = described_class.new("76561197960287930")
        expect(service.search).to eq([ user ])
      end
    end

    context "with Steam ID" do
      it "finds user by Steam ID format" do
        allow(SteamCondenser::Community::SteamId).to receive(:steam_id_to_community_id)
          .with("STEAM_0:0:115582")
          .and_return(76561197960287930)

        service = described_class.new("STEAM_0:0:115582")
        expect(service.search).to eq([ user ])
      end
    end

    context "with Steam ID3" do
      it "finds user by Steam ID3 format" do
        allow(SteamCondenser::Community::SteamId).to receive(:steam_id_to_community_id)
          .with("[U:1:231164]")
          .and_return(76561197960287930)

        service = described_class.new("[U:1:231164]")
        expect(service.search).to eq([ user ])
      end
    end

    context "with Steam URL" do
      it "finds user by Steam profile URL" do
        service = described_class.new("https://steamcommunity.com/profiles/76561197960287930")
        expect(service.search).to eq([ user ])
      end

      it "finds user by Steam vanity URL" do
        allow(SteamCondenser::Community::SteamId).to receive(:resolve_vanity_url)
          .with("testplayer")
          .and_return(76561197960287930)

        service = described_class.new("https://steamcommunity.com/id/testplayer")
        expect(service.search).to eq([ user ])
      end

      it "returns empty array when URL cannot be resolved" do
        allow(SteamCondenser::Community::SteamId).to receive(:resolve_vanity_url)
          .with("nonexistent")
          .and_return(nil)

        service = described_class.new("https://steamcommunity.com/id/nonexistent")
        expect(service.search).to eq([])
      end

      context "with real Steam API call", :vcr do
        it "resolves vanity URL ariekanarie" do
          # Create a user with the expected Steam ID
          ariekanarie_user = create(:user, uid: "76561197960497430", nickname: "Arie")

          service = described_class.new("https://steamcommunity.com/id/ariekanarie")
          expect(service.search).to eq([ ariekanarie_user ])
        end
      end
    end

    context "with nickname" do
      let!(:other_user1) { create(:user, nickname: "PlayerTest") }
      let!(:other_user2) { create(:user, nickname: "SomeTestUser") }

      it "finds users by partial nickname match" do
        service = described_class.new("Test")
        results = service.search

        expect(results).to include(user, other_user1, other_user2)
        expect(results.size).to be <= 5
      end

      it "orders by exact match first" do
        exact_match = create(:user, nickname: "Test")

        service = described_class.new("Test")
        results = service.search

        expect(results.first).to eq(exact_match)
      end

      it "is case insensitive" do
        service = described_class.new("testplayer")
        expect(service.search).to include(user)
      end
    end
  end
end
