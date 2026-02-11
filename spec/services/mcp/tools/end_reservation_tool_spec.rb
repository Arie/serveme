# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::EndReservationTool do
  describe "class methods" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("end_reservation")
    end

    it "has a description" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end

    it "requires public role" do
      expect(described_class.required_role).to eq(:public)
    end

    it "has an input schema with reservation_id" do
      schema = described_class.input_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to have_key(:reservation_id)
      expect(schema[:required]).to include("reservation_id")
    end
  end

  describe ".available_to?" do
    it "is available to regular users" do
      user = create(:user)
      expect(described_class.available_to?(user)).to be true
    end
  end

  describe "#execute" do
    let(:owner) { create(:user, uid: "76561198012345678") }
    let(:server) { create(:server) }

    let!(:active_reservation) do
      create(:reservation,
        server: server,
        user: owner,
        starts_at: 10.minutes.ago,
        ends_at: 50.minutes.from_now,
        provisioned: true
      )
    end

    context "when API user is the reservation owner" do
      let(:tool) { described_class.new(owner) }

      before do
        allow_any_instance_of(Reservation).to receive(:end_reservation)
      end

      it "ends the reservation successfully" do
        result = tool.execute(reservation_id: active_reservation.id)

        expect(result[:success]).to be true
        expect(result[:message]).to include("ended successfully")
        expect(result[:reservation][:id]).to eq(active_reservation.id)
      end

      it "calls end_reservation on the reservation" do
        expect_any_instance_of(Reservation).to receive(:end_reservation)

        tool.execute(reservation_id: active_reservation.id)
      end
    end

    context "when API user is an admin (privileged)" do
      let(:admin_user) { create(:user, :admin) }
      let(:tool) { described_class.new(admin_user) }

      before do
        allow_any_instance_of(Reservation).to receive(:end_reservation)
      end

      it "can end any reservation" do
        result = tool.execute(reservation_id: active_reservation.id)

        expect(result[:success]).to be true
      end
    end

    context "when API user does not own the reservation" do
      let(:other_user) { create(:user, uid: "76561198099999999") }
      let(:tool) { described_class.new(other_user) }

      it "returns authorization error" do
        result = tool.execute(reservation_id: active_reservation.id)

        expect(result[:error]).to include("Not authorized")
      end
    end

    context "with missing reservation_id" do
      let(:tool) { described_class.new(owner) }

      it "returns error" do
        result = tool.execute({})

        expect(result[:error]).to include("reservation_id is required")
      end
    end

    context "with invalid reservation_id" do
      let(:tool) { described_class.new(owner) }

      it "returns error if reservation not found" do
        result = tool.execute(reservation_id: 999999)

        expect(result[:error]).to include("not found")
      end
    end

    context "when reservation has already ended" do
      let(:ended_owner) { create(:user, uid: "76561198011111111") }
      let(:ended_server) { create(:server, name: "Ended Reservation Server") }
      let(:ended_reservation) do
        reservation = create(:reservation, server: ended_server, user: ended_owner)
        reservation.update_columns(
          starts_at: 2.hours.ago,
          ends_at: 1.hour.ago,
          ended: true
        )
        reservation.reload
      end
      let(:tool) { described_class.new(ended_owner) }

      it "returns error" do
        result = tool.execute(reservation_id: ended_reservation.id)

        expect(result[:error]).to include("already ended")
      end
    end

    context "when reservation is scheduled for the future" do
      let(:future_server) { create(:server, name: "Future Server") }
      let(:future_reservation) do
        create(:reservation,
          server: future_server,
          user: owner,
          starts_at: 1.hour.from_now,
          ends_at: 3.hours.from_now
        )
      end
      let(:tool) { described_class.new(owner) }

      it "returns error" do
        result = tool.execute(reservation_id: future_reservation.id)

        expect(result[:error]).to include("future reservation")
      end
    end
  end
end
