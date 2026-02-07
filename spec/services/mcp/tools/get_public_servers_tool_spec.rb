# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::GetPublicServersTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("get_public_servers")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires public role (available to all)" do
      expect(described_class.required_role).to eq(:public)
    end

    it "has an input schema with location filter" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:location)
    end
  end

  describe ".available_to?" do
    it "is available to regular users" do
      user = create(:user)
      expect(described_class.available_to?(user)).to be true
    end

    it "is available to admins" do
      user = create(:user, :admin)
      expect(described_class.available_to?(user)).to be true
    end
  end

  describe "#execute" do
    let(:user) { create(:user) }
    let(:tool) { described_class.new(user) }

    let!(:active_server) { create(:server, name: "Active Server", active: true) }
    let!(:inactive_server) { create(:server, name: "Inactive Server", active: false) }

    context "with default parameters" do
      it "returns only active servers" do
        result = tool.execute({})

        expect(result[:servers]).to be_an(Array)
        server_names = result[:servers].map { |s| s[:name] }
        expect(server_names).to include("Active Server")
        expect(server_names).not_to include("Inactive Server")
      end

      it "includes server count" do
        result = tool.execute({})

        expect(result[:server_count]).to be_a(Integer)
        expect(result[:server_count]).to be >= 1
      end
    end

    context "with location filter" do
      let(:eu_location) { create(:location, name: "FilterTestEU", flag: "nl") }
      let(:us_location) { create(:location, name: "FilterTestUS", flag: "us") }
      let!(:eu_server) { create(:server, name: "EU Server", active: true, location: eu_location) }
      let!(:us_server) { create(:server, name: "US Server", active: true, location: us_location) }

      it "filters by location name" do
        result = tool.execute(location: "FilterTestEU")

        server_names = result[:servers].map { |s| s[:name] }
        expect(server_names).to include("EU Server")
        expect(server_names).not_to include("US Server")
      end
    end

    it "returns public server info without sensitive data" do
      result = tool.execute({})

      server = result[:servers].find { |s| s[:name] == "Active Server" }
      expect(server).not_to be_nil

      # Should have public info
      expect(server).to include(:id, :name, :location, :flag, :available)

      # Should NOT have sensitive info (IP, RCON password, etc.)
      expect(server).not_to have_key(:ip)
      expect(server).not_to have_key(:rcon)
    end

    it "includes availability status" do
      result = tool.execute({})

      server = result[:servers].find { |s| s[:name] == "Active Server" }
      expect(server).to have_key(:available)
      expect(server[:available]).to be_in([ true, false ])
    end
  end
end
