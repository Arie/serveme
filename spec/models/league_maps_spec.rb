# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe LeagueMaps do
  let(:mock_config) do
    {
      "league_maps" => [
        {
          "name" => "Test 6v6",
          "active" => true,
          "maps" => [ "cp_granary", "cp_process" ]
        },
        {
          "name" => "Test HL",
          "active" => true,
          "maps" => [ "pl_upward", "koth_product" ]
        },
        {
          "name" => "Inactive League",
          "active" => false,
          "maps" => [ "cp_inactive" ]
        }
      ]
    }
  end

  let(:sync_service) { LeagueMapsSyncService.new }

  before do
    allow(LeagueMapsSyncService).to receive(:new).and_return(sync_service)
    allow(sync_service).to receive(:current_config)
      .and_return(mock_config)
  end

  describe ".all" do
    before do
      allow(MapUpload).to receive(:available_maps).and_return([ "dm_mariokart", "cp_orange" ])
    end

    it "returns all active leagues plus 'All maps'" do
      result = described_class.all

      expect(result).to have(3).items
      expect(result.first.name).to eq("Test 6v6")
      expect(result.second.name).to eq("Test HL")
      expect(result.last.name).to eq("All maps")
    end

    it "excludes inactive leagues" do
      league_names = described_class.all.map(&:name)
      expect(league_names).not_to include("Inactive League")
    end
  end

  describe ".grouped_league_maps" do
    it "returns only active leagues from config" do
      result = described_class.grouped_league_maps

      expect(result).to have(2).items
      expect(result.map(&:name)).to contain_exactly("Test 6v6", "Test HL")
    end

    it "creates LeagueMaps objects with sorted maps" do
      result = described_class.grouped_league_maps

      test_6v6 = result.find { |l| l.name == "Test 6v6" }
      expect(test_6v6.maps).to eq([ "cp_granary", "cp_process" ])
    end

    it "handles empty config gracefully" do
      allow(sync_service).to receive(:current_config)
        .and_return({})

      result = described_class.grouped_league_maps
      expect(result).to be_empty
    end
  end

  describe ".all_league_maps" do
    it "returns all maps from all active leagues" do
      result = described_class.all_league_maps

      expect(result).to contain_exactly("cp_granary", "cp_process", "koth_product", "pl_upward")
    end

    it "returns unique sorted maps" do
      config_with_duplicates = {
        "league_maps" => [
          { "name" => "League 1", "active" => true, "maps" => [ "cp_granary", "cp_process" ] },
          { "name" => "League 2", "active" => true, "maps" => [ "cp_process", "koth_product" ] }
        ]
      }

      allow(sync_service).to receive(:current_config)
        .and_return(config_with_duplicates)

      result = described_class.all_league_maps
      expect(result).to eq([ "cp_granary", "cp_process", "koth_product" ])
    end
  end


  describe "error handling" do
    it "handles service errors gracefully" do
      allow(sync_service).to receive(:current_config)
        .and_raise(StandardError.new("Service error"))

      expect { described_class.grouped_league_maps }.to raise_error(StandardError, "Service error")
    end
  end

  describe "initialization" do
    it "creates LeagueMaps object with name and maps" do
      league_maps = described_class.new(name: "Test League", maps: [ "cp_test" ])

      expect(league_maps.name).to eq("Test League")
      expect(league_maps.maps).to eq([ "cp_test" ])
    end
  end
end
