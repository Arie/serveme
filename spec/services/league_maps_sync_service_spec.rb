# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe LeagueMapsSyncService do
  let(:service) { described_class.new }

  let(:valid_yaml_config) do
    {
      "league_maps" => [
        {
          "name" => "Test League",
          "active" => true,
          "maps" => [ "cp_test_map", "koth_test_map" ]
        },
        {
          "name" => "Inactive League",
          "active" => false,
          "maps" => [ "cp_inactive_map" ]
        }
      ]
    }
  end

  let(:invalid_yaml_config) do
    {
      "wrong_key" => []
    }
  end

  describe ".fetch_and_apply" do
    it "fetches, validates and applies valid config" do
      allow_any_instance_of(described_class).to receive(:fetch_from_github).and_return(valid_yaml_config)
      allow(MapUpload).to receive(:available_maps).and_return([ "cp_test_map", "koth_test_map" ])

      expect(Rails.cache).to receive(:write).with(
        "league_maps_config",
        valid_yaml_config,
        expires_in: 24.hours
      )
      expect(Rails.cache).to receive(:write).with(
        "league_maps_config_last_sync",
        kind_of(Time),
        expires_in: 24.hours
      )

      result = described_class.fetch_and_apply
      expect(result).to be true
    end

    it "returns false when fetch fails" do
      allow_any_instance_of(described_class).to receive(:fetch_from_github).and_return({})

      result = described_class.fetch_and_apply
      expect(result).to be false
    end

    it "returns false when validation fails" do
      allow_any_instance_of(described_class).to receive(:fetch_from_github).and_return(invalid_yaml_config)

      result = described_class.fetch_and_apply
      expect(result).to be false
    end
  end

  describe "#fetch_from_github" do
    before do
      stub_const("LeagueMapsSyncService::GITHUB_RAW_URL",
                "https://example.com/test-config.yml")
    end

    it "successfully fetches valid YAML from GitHub" do
      stub_request(:get, /https:\/\/example\.com\/test-config\.yml\?cachebust=\d+/)
        .to_return(status: 200, body: valid_yaml_config.to_yaml)

      result = service.fetch_from_github
      expect(result).to eq(valid_yaml_config)
    end

    it "returns empty hash on HTTP error" do
      stub_request(:get, /https:\/\/example\.com\/test-config\.yml\?cachebust=\d+/)
        .to_return(status: 404, body: "Not Found")

      result = service.fetch_from_github
      expect(result).to eq({})
    end

    it "returns empty hash on network error" do
      stub_request(:get, /https:\/\/example\.com\/test-config\.yml\?cachebust=\d+/)
        .to_raise(StandardError.new("Network error"))

      result = service.fetch_from_github
      expect(result).to eq({})
    end

    it "returns empty hash on invalid YAML" do
      stub_request(:get, /https:\/\/example\.com\/test-config\.yml\?cachebust=\d+/)
        .to_return(status: 200, body: "invalid: yaml: content: [")

      result = service.fetch_from_github
      expect(result).to eq({})
    end
  end

  describe "#validate_config" do
    before do
      allow(MapUpload).to receive(:available_maps).and_return([
        "cp_test_map", "koth_test_map", "pl_test_map"
      ])
    end

    it "validates correct config structure" do
      result = service.validate_config(valid_yaml_config)

      expect(result[:valid]).to be true
      expect(result[:errors]).to be_empty
    end

    it "detects missing league_maps key" do
      result = service.validate_config({ "wrong_key" => [] })

      expect(result[:valid]).to be false
      expect(result[:errors]).to include(
        "Invalid YAML structure - expected 'league_maps' array at root level"
      )
    end

    it "detects empty leagues" do
      config = { "league_maps" => [] }
      result = service.validate_config(config)

      expect(result[:valid]).to be false
      expect(result[:errors]).to include("No league maps defined")
    end

    it "detects missing league name" do
      config = {
        "league_maps" => [
          { "maps" => [ "cp_test_map" ] }
        ]
      }
      result = service.validate_config(config)

      expect(result[:valid]).to be false
      expect(result[:errors]).to include(
        "League at index 0 missing required 'name' field"
      )
    end

    it "detects duplicate league names" do
      config = {
        "league_maps" => [
          { "name" => "Test League", "maps" => [ "cp_test_map" ] },
          { "name" => "Test League", "maps" => [ "koth_test_map" ] }
        ]
      }
      result = service.validate_config(config)

      expect(result[:valid]).to be false
      expect(result[:errors]).to include("Duplicate league name: Test League")
    end

    it "warns about unknown maps" do
      config = {
        "league_maps" => [
          { "name" => "Test League", "maps" => [ "cp_unknown_map" ] }
        ]
      }
      result = service.validate_config(config)

      expect(result[:valid]).to be true
      expect(result[:warnings]).to include(
        "League 'Test League' contains unknown map: cp_unknown_map"
      )
    end

    it "warns about empty leagues" do
      config = {
        "league_maps" => [
          { "name" => "Empty League", "maps" => [] }
        ]
      }
      result = service.validate_config(config)

      expect(result[:valid]).to be true
      expect(result[:warnings]).to include(
        "League 'Empty League' has no maps defined"
      )
    end
  end

  describe "#apply_config" do
    it "writes config to cache with expiry" do
      expect(Rails.cache).to receive(:write).with(
        "league_maps_config",
        valid_yaml_config,
        expires_in: 24.hours
      )
      expect(Rails.cache).to receive(:write).with(
        "league_maps_config_last_sync",
        kind_of(Time),
        expires_in: 24.hours
      )
      expect(service).to receive(:write_local_config).with(valid_yaml_config)

      result = service.apply_config(valid_yaml_config)
      expect(result).to be true
    end
  end

  describe "#current_config" do
    it "returns config from cache" do
      expect(Rails.cache).to receive(:fetch).with("league_maps_config")
                                          .and_return(valid_yaml_config)

      result = service.current_config
      expect(result).to eq(valid_yaml_config)
    end

    it "loads local fallback when cache empty" do
      expect(Rails.cache).to receive(:fetch).with("league_maps_config")
                                          .and_yield

      yaml_path = Rails.root.join("config", "league_maps.yml")
      expect(File).to receive(:read).with(yaml_path).and_return(valid_yaml_config.to_yaml)
      expect(YAML).to receive(:safe_load).with(valid_yaml_config.to_yaml, permitted_classes: [ Symbol ]).and_return(valid_yaml_config)

      result = service.current_config
      expect(result).to eq(valid_yaml_config)
    end
  end

  describe "#generate_diff" do
    let(:current_config) do
      {
        "league_maps" => [
          { "name" => "Existing League", "maps" => [ "cp_old_map", "koth_shared_map" ] }
        ]
      }
    end

    let(:new_config) do
      {
        "league_maps" => [
          { "name" => "New League", "maps" => [ "cp_new_map" ] },
          { "name" => "Existing League", "maps" => [ "cp_new_map", "koth_shared_map" ] }
        ]
      }
    end

    before do
      allow(service).to receive(:current_config).and_return(current_config)
    end

    it "generates correct diff between configs" do
      diff = service.generate_diff(new_config)

      expect(diff[:added_leagues]).to eq([ "New League" ])
      expect(diff[:removed_leagues]).to be_empty
      expect(diff[:modified_leagues]).to contain_exactly({
        name: "Existing League",
        added_maps: [ "cp_new_map" ],
        removed_maps: [ "cp_old_map" ]
      })
    end
  end
end
