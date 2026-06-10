# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mcp::Tools::CreateReservationTool do
  let(:user) { create(:user, uid: "76561198012345678") }
  let(:tool) { described_class.new(user) }

  before do
    allow(CloudServerProvisionWorker).to receive(:perform_async)
    allow(DockerImageReadiness).to receive(:stale?).and_return(false)
    allow(MapUpload).to receive(:available_maps).and_return(%w[cp_badlands])
  end

  describe "#execute" do
    context "auto-selecting a server" do
      it "picks an available regular server" do
        server = create(:server)

        result = tool.execute(password: "secret")

        expect(result[:success]).to be true
        expect(result[:reservation][:server_name]).to eq(server.name)
      end

      it "falls back to a remote-docker host when no regular server is free" do
        docker_host = create(:docker_host)

        result = tool.execute(password: "secret")

        expect(result[:success]).to be true
        reservation = Reservation.find(result[:reservation][:id])
        expect(reservation.server).to be_a(CloudServer)
        expect(reservation.server.cloud_provider).to eq("remote_docker")
        expect(reservation.server.cloud_location).to eq(docker_host.id.to_s)
      end

      it "errors when neither a regular server nor a docker host is available" do
        result = tool.execute(password: "secret")

        expect(result[:error]).to be_present
      end
    end

    context "explicitly requesting a remote-docker host" do
      it "books on the requested docker host via its virtual id" do
        docker_host = create(:docker_host)

        result = tool.execute(password: "secret", server_id: docker_host.virtual_server_id)

        expect(result[:success]).to be true
        reservation = Reservation.find(result[:reservation][:id])
        expect(reservation.server).to be_a(CloudServer)
        expect(reservation.server.cloud_location).to eq(docker_host.id.to_s)
      end

      it "errors when the docker host does not exist" do
        result = tool.execute(password: "secret", server_id: DockerHost::VIRTUAL_ID_OFFSET + 999_999)

        expect(result[:error]).to eq("Server not found")
      end
    end
  end
end
