# typed: false
# frozen_string_literal: true

require "spec_helper"

describe DockerHostImagePullWorker do
  let(:worker) { described_class.new }

  describe "#perform" do
    context "without docker_host_id (fan-out mode)" do
      it "enqueues a job per active docker host" do
        host1 = create(:docker_host)
        host2 = create(:docker_host, hostname: "de2.serveme.tf")

        expect(DockerHostImagePullWorker).to receive(:perform_async).with(host1.id)
        expect(DockerHostImagePullWorker).to receive(:perform_async).with(host2.id)

        worker.perform
      end

      it "does nothing when no active docker hosts" do
        allow(DockerHost).to receive(:active).and_return(DockerHost.none)

        expect(DockerHostImagePullWorker).not_to receive(:perform_async)

        worker.perform
      end
    end

    context "with docker_host_id (pull mode)" do
      it "pulls the image on the specified host" do
        host = create(:docker_host)

        ssh = instance_double(Net::SSH::Connection::Session)
        allow(Net::SSH).to receive(:start).and_yield(ssh)
        allow(ssh).to receive(:exec!).and_return("Status: Image is up to date for serveme/tf2-cloud-server:latest")

        worker.perform(host.id)

        expect(Net::SSH).to have_received(:start).with(host.hostname, "tf2", hash_including(timeout: 5))
      end

      it "raises on SSH failure so Sidekiq retries" do
        host = create(:docker_host)

        allow(Net::SSH).to receive(:start).and_raise(Errno::ECONNREFUSED)

        expect { worker.perform(host.id) }.to raise_error(Errno::ECONNREFUSED)
      end
    end
  end
end
