# typed: false
# frozen_string_literal: true

require "spec_helper"

describe UserFinderService do
  let!(:user) { create(:user, uid: "76561197960287930", nickname: "TestPlayer") }

  describe "#find" do
    context "with user ID" do
      it "finds user by ID with # prefix" do
        finder = UserFinderService.new("##{user.id}")
        expect(finder.find).to eq(user)
      end

      it "finds user by ID without # prefix" do
        finder = UserFinderService.new(user.id.to_s)
        expect(finder.find).to eq(user)
      end
    end

    context "with Steam ID64" do
      it "finds user by Steam ID64" do
        finder = UserFinderService.new(user.uid)
        expect(finder.find).to eq(user)
      end
    end

    context "with Steam ID" do
      it "finds user by Steam ID format" do
        finder = UserFinderService.new("STEAM_0:0:11101")
        expect(finder.find).to eq(user)
      end

      it "handles invalid Steam ID gracefully" do
        finder = UserFinderService.new("STEAM_invalid")
        expect(finder.find).to be_nil
      end
    end

    context "with Steam ID3" do
      it "finds user by Steam ID3 format" do
        finder = UserFinderService.new("[U:1:22202]")
        expect(finder.find).to eq(user)
      end

      it "handles invalid Steam ID3 gracefully" do
        finder = UserFinderService.new("[U:invalid]")
        expect(finder.find).to be_nil
      end
    end

    context "with nickname" do
      it "finds user by exact nickname" do
        finder = UserFinderService.new("TestPlayer")
        expect(finder.find).to eq(user)
      end

      it "finds user by partial nickname" do
        finder = UserFinderService.new("testpl")
        expect(finder.find).to eq(user)
      end

      it "is case insensitive" do
        finder = UserFinderService.new("TESTPLAYER")
        expect(finder.find).to eq(user)
      end

      it "does not search by nickname if input looks like an ID" do
        create(:user, nickname: "12345")
        finder = UserFinderService.new("12345")
        expect(finder.find).to be_nil
      end
    end

    context "with blank input" do
      it "returns nil for empty string" do
        finder = UserFinderService.new("")
        expect(finder.find).to be_nil
      end

      it "returns nil for nil input" do
        finder = UserFinderService.new(nil)
        expect(finder.find).to be_nil
      end

      it "returns nil for whitespace only" do
        finder = UserFinderService.new("   ")
        expect(finder.find).to be_nil
      end
    end

    context "with no matching user" do
      it "returns nil when user not found" do
        finder = UserFinderService.new("nonexistent")
        expect(finder.find).to be_nil
      end
    end
  end
end
