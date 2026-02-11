# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::SearchReservationLogsTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("search_reservation_logs")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires admin role" do
      expect(described_class.required_role).to eq(:admin)
    end

    it "has an input schema with reservation_id property" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:reservation_id)
      expect(schema[:properties]).to have_key(:search_term)
      expect(schema[:properties]).to have_key(:context_lines)
      expect(schema[:properties]).to have_key(:max_results)
      expect(schema[:properties]).to have_key(:offset)
      expect(schema[:required]).to include("reservation_id")
    end
  end

  describe "#execute" do
    let(:admin_user) { create(:user, :admin) }
    let(:tool) { described_class.new(admin_user) }
    let(:server) { create(:server) }
    let!(:reservation) do
      create(:reservation, server: server, logsecret: "testsecret123")
    end

    let(:log_dir) { Rails.root.join("log", "streaming") }
    let(:log_file) { log_dir.join("#{reservation.logsecret}.log") }

    let(:log_content) do
      <<~LOG
        L 01/15/2026 - 20:00:01: Log file started
        L 01/15/2026 - 20:00:02: "PlayerOne<2><[U:1:12345]><>" connected, address "192.168.1.100:27005"
        L 01/15/2026 - 20:00:03: "PlayerTwo<3><[U:1:67890]><>" connected, address "10.0.0.50:27005"
        L 01/15/2026 - 20:00:10: "PlayerOne<2><[U:1:12345]><Red>" say "gg"
        L 01/15/2026 - 20:00:11: "PlayerTwo<3><[U:1:67890]><Blue>" say "gg wp"
        L 01/15/2026 - 20:00:15: "PlayerOne<2><[U:1:12345]><Red>" killed "PlayerTwo<3><[U:1:67890]><Blue>"
        L 01/15/2026 - 20:00:20: Log file closed
      LOG
    end

    before do
      FileUtils.mkdir_p(log_dir)
      File.write(log_file, log_content)
    end

    after do
      File.delete(log_file) if File.exist?(log_file)
    end

    context "with valid reservation and search term" do
      it "returns matching lines" do
        result = tool.execute(reservation_id: reservation.id, search_term: "PlayerOne")

        expect(result[:reservation_id]).to eq(reservation.id)
        expect(result[:lines]).to be_an(Array)
        expect(result[:lines].size).to eq(3)
        expect(result[:match_count]).to eq(3)
        expect(result[:lines]).to all(include("PlayerOne"))
      end

      it "searches case-insensitively" do
        result = tool.execute(reservation_id: reservation.id, search_term: "playerone")

        expect(result[:lines].size).to eq(3)
      end

      it "finds chat messages" do
        result = tool.execute(reservation_id: reservation.id, search_term: "say \"gg")

        expect(result[:lines].size).to eq(2)
      end
    end

    context "with no search term" do
      it "returns the full log content" do
        result = tool.execute(reservation_id: reservation.id)

        expect(result[:reservation_id]).to eq(reservation.id)
        expect(result[:lines]).to be_an(Array)
        expect(result[:lines].size).to eq(7)
        expect(result[:truncated]).to be false
      end
    end

    context "with context_lines parameter" do
      it "includes context around matches" do
        result = tool.execute(reservation_id: reservation.id, search_term: "killed", context_lines: 1)

        expect(result[:lines]).to be_an(Array)
        expect(result[:lines].size).to be > 1
      end
    end

    context "with max_results cap" do
      it "limits the number of results" do
        result = tool.execute(reservation_id: reservation.id, search_term: "PlayerOne", max_results: 2)

        expect(result[:lines].size).to eq(2)
        expect(result[:truncated]).to be true
      end

      it "limits tail output when no search term" do
        result = tool.execute(reservation_id: reservation.id, max_results: 3)

        expect(result[:lines].size).to eq(3)
        expect(result[:truncated]).to be true
      end
    end

    context "with offset parameter" do
      it "skips matches when searching" do
        all_results = tool.execute(reservation_id: reservation.id, search_term: "PlayerOne")
        offset_results = tool.execute(reservation_id: reservation.id, search_term: "PlayerOne", offset: 1)

        expect(offset_results[:lines].size).to eq(2)
        expect(offset_results[:lines]).to eq(all_results[:lines][1..])
        expect(offset_results[:offset]).to eq(1)
        expect(offset_results[:truncated]).to be false
      end

      it "paginates search results with offset and max_results" do
        page1 = tool.execute(reservation_id: reservation.id, search_term: "PlayerOne", max_results: 2, offset: 0)
        page2 = tool.execute(reservation_id: reservation.id, search_term: "PlayerOne", max_results: 2, offset: 2)

        expect(page1[:lines].size).to eq(2)
        expect(page1[:truncated]).to be true
        expect(page2[:lines].size).to eq(1)
        expect(page2[:truncated]).to be false
      end

      it "returns empty when offset exceeds matches" do
        result = tool.execute(reservation_id: reservation.id, search_term: "PlayerOne", offset: 100)

        expect(result[:lines]).to be_empty
        expect(result[:truncated]).to be false
      end

      it "reads from offset when tailing without search term" do
        result = tool.execute(reservation_id: reservation.id, offset: 2, max_results: 3)

        expect(result[:lines].size).to eq(3)
        expect(result[:offset]).to eq(2)
        expect(result[:lines].first).to include("PlayerTwo")
        expect(result[:truncated]).to be true
      end
    end

    context "with non-existent reservation" do
      it "returns error" do
        result = tool.execute(reservation_id: 999999)

        expect(result[:error]).to include("not found")
      end
    end

    context "with reservation that has no log file" do
      let(:other_server) { create(:server, name: "No Log Server") }
      let!(:no_log_reservation) do
        create(:reservation, server: other_server, logsecret: "nonexistent_secret")
      end

      it "returns error" do
        result = tool.execute(reservation_id: no_log_reservation.id)

        expect(result[:error]).to include("No log file found")
      end
    end

    context "with missing reservation_id" do
      it "returns error" do
        result = tool.execute({})

        expect(result[:error]).to include("reservation_id is required")
      end
    end

    context "with reservation that has no logsecret" do
      let(:another_server) { create(:server, name: "No Secret Server") }
      let!(:no_secret_reservation) do
        res = create(:reservation, server: another_server)
        res.update_columns(logsecret: nil)
        res.reload
      end

      it "returns error" do
        result = tool.execute(reservation_id: no_secret_reservation.id)

        expect(result[:error]).to include("No log file found")
      end
    end
  end
end
