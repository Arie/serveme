# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::ListServersTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("list_servers")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires admin role" do
      expect(described_class.required_role).to eq(:admin)
    end

    it "has an input schema" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:active_only)
      expect(schema[:properties]).to have_key(:include_reservation)
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }
    let!(:server) { create(:server, name: "Test Server 1", active: true) }
    let!(:inactive_server) { create(:server, name: "Inactive Server", active: false) }

    context "with default parameters" do
      it "returns all active servers" do
        result = tool.execute({})

        expect(result[:servers]).to be_an(Array)
        expect(result[:servers].map { |s| s[:name] }).to include("Test Server 1")
        expect(result[:servers].map { |s| s[:name] }).not_to include("Inactive Server")
      end
    end

    context "with active_only: false" do
      it "returns all servers including inactive" do
        result = tool.execute(active_only: false)

        server_names = result[:servers].map { |s| s[:name] }
        expect(server_names).to include("Test Server 1")
        expect(server_names).to include("Inactive Server")
      end
    end

    context "server with current reservation" do
      let!(:reservation) do
        create(:reservation,
          server: server,
          starts_at: 10.minutes.ago,
          ends_at: 50.minutes.from_now
        )
      end

      it "includes current reservation info when requested" do
        result = tool.execute(include_reservation: true)

        server_info = result[:servers].find { |s| s[:name] == "Test Server 1" }
        expect(server_info[:current_reservation]).to be_present
        expect(server_info[:current_reservation][:id]).to eq(reservation.id)
      end
    end

    it "includes server details" do
      result = tool.execute({})

      server_info = result[:servers].find { |s| s[:name] == "Test Server 1" }
      expect(server_info).to include(
        :id,
        :name,
        :ip,
        :port,
        :active
      )
    end
  end
end
