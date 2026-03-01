# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe CloudServer do
  describe '#mark_ready!' do
    it 'updates cloud_status to ready' do
      server = create(:cloud_server, cloud_status: 'provisioning')
      server.mark_ready!
      expect(server.reload.cloud_status).to eq('ready')
    end
  end

  describe '#ssh' do
    it 'uses explicit key auth with key_data, keys_only, and verify_host_key' do
      subject.stub(ip: '1.2.3.4')
      allow(subject).to receive(:cloud_ssh_private_key).and_return('fake-key')
      Net::SSH.should_receive(:start).with('1.2.3.4', 'tf2',
        port: 22,
        key_data: [ 'fake-key' ],
        keys_only: true,
        non_interactive: true,
        verify_host_key: :never)
      subject.ssh
    end
  end

  describe '#scp_command' do
    it 'includes -i flag for key-based auth' do
      allow(subject).to receive(:cloud_ssh_private_key).and_return('fake-key')
      expect(subject.send(:scp_command)).to match(/-i .+ -o StrictHostKeyChecking=no/)
    end
  end

  describe '#find_process_id' do
    it 'finds correct pid for regular servers' do
      subject.stub(port: '27015')
      subject.stub(team_comtress_server?: false)
      subject.should_receive(:execute).with("ps ux | grep port | grep #{subject.port} | grep srcds_linux | grep -v grep | grep -v ruby | awk '{print $2}'")
      subject.find_process_id
    end
  end

  describe '#demos' do
    it 'finds the demo files' do
      subject.stub(:shell_output_to_array)
      subject.stub(tf_dir: 'foo')
      subject.should_receive(:execute).with("ls #{subject.tf_dir}/*.dem")
      subject.demos
    end
  end

  describe '#logs' do
    it 'finds the log files' do
      subject.stub(:shell_output_to_array)
      subject.stub(tf_dir: 'foo')
      subject.should_receive(:execute).with("ls #{subject.tf_dir}/logs/*.log")
      subject.logs
    end
  end

  describe '#restart' do
    it 'sends the software termination signal to the process' do
      subject.stub(process_id: 1337)
      allow(subject).to receive(:cloud_ssh_private_key).and_return('fake-key')
      Net::SSH.should_receive(:start).with(subject.ip, 'tf2',
        port: 22,
        key_data: [ 'fake-key' ],
        keys_only: true,
        non_interactive: true,
        verify_host_key: :never)
      subject.should_receive(:execute).with("kill -15 #{subject.process_id}")
      subject.restart
    end
  end

  describe '.next_available_docker_port' do
    it 'returns 27015 when no docker servers exist' do
      expect(CloudServer.next_available_docker_port).to eq(27015)
    end

    it 'returns the next port when 27015 is in use' do
      create(:cloud_server, cloud_provider: 'docker', port: '27015', cloud_status: 'ready', cloud_location: 'local')
      expect(CloudServer.next_available_docker_port).to eq(27025)
    end

    it 'skips ports that are in use' do
      create(:cloud_server, cloud_provider: 'docker', port: '27015', cloud_status: 'ready', cloud_location: 'local')
      create(:cloud_server, cloud_provider: 'docker', port: '27025', cloud_status: 'provisioning', cloud_location: 'local')
      expect(CloudServer.next_available_docker_port).to eq(27035)
    end

    it 'reuses ports from destroyed servers' do
      create(:cloud_server, cloud_provider: 'docker', port: '27015', cloud_status: 'destroyed', cloud_location: 'local')
      expect(CloudServer.next_available_docker_port).to eq(27015)
    end

    it 'ignores non-docker providers' do
      create(:cloud_server, cloud_provider: 'hetzner', port: '27015', cloud_status: 'ready', cloud_location: 'local')
      expect(CloudServer.next_available_docker_port).to eq(27015)
    end

    it 'fills gaps in port allocation' do
      create(:cloud_server, cloud_provider: 'docker', port: '27015', cloud_status: 'ready', cloud_location: 'local')
      create(:cloud_server, cloud_provider: 'docker', port: '27035', cloud_status: 'ready', cloud_location: 'local')
      expect(CloudServer.next_available_docker_port).to eq(27025)
    end
  end

  describe '#supports_mitigations?' do
    it 'returns true for non-docker providers' do
      subject.cloud_provider = "hetzner"
      expect(subject.supports_mitigations?).to be true
    end

    it 'returns true for docker provider' do
      subject.cloud_provider = "docker"
      expect(subject.supports_mitigations?).to be true
    end

    it 'returns true for remote_docker provider' do
      subject.cloud_provider = "remote_docker"
      expect(subject.supports_mitigations?).to be true
    end
  end

  describe '#mitigation_ssh_exec' do
    it 'SSHs to the docker host for remote_docker provider' do
      docker_host = create(:docker_host)
      subject.cloud_provider = "remote_docker"
      subject.cloud_location = docker_host.id.to_s

      ssh_session = double
      expect(Net::SSH).to receive(:start).with(docker_host.ip, nil).and_yield(ssh_session)
      expect(ssh_session).to receive(:exec!).with("test command").and_yield(nil, :stdout, "output")

      result = subject.mitigation_ssh_exec("test command")
      expect(result).to eq("output")
    end

    it 'runs locally for docker provider' do
      subject.cloud_provider = "docker"
      expect(Open3).to receive(:capture3).with("test command").and_return([ "output", "", double ])

      result = subject.mitigation_ssh_exec("test command")
      expect(result).to eq("output")
    end

    it 'falls back to regular ssh_exec for other providers' do
      subject.cloud_provider = "hetzner"
      expect(subject).to receive(:ssh_exec).with("test command", log_stderr: false).and_return("output")

      result = subject.mitigation_ssh_exec("test command")
      expect(result).to eq("output")
    end
  end

  describe '#uses_async_cleanup?' do
    it 'returns true' do
      expect(subject.uses_async_cleanup?).to be true
    end
  end

  describe '.next_available_port_for' do
    context 'with remote_docker provider' do
      let(:docker_host) { create(:docker_host, start_port: 27115) }

      it 'returns start_port when no servers exist' do
        expect(CloudServer.next_available_port_for('remote_docker', docker_host.id.to_s)).to eq(27115)
      end

      it 'returns the next port when start_port is in use' do
        create(:cloud_server, cloud_provider: 'remote_docker', port: '27115', cloud_status: 'ready', cloud_location: docker_host.id.to_s)
        expect(CloudServer.next_available_port_for('remote_docker', docker_host.id.to_s)).to eq(27125)
      end

      it 'reuses ports from destroyed servers' do
        create(:cloud_server, cloud_provider: 'remote_docker', port: '27115', cloud_status: 'destroyed', cloud_location: docker_host.id.to_s)
        expect(CloudServer.next_available_port_for('remote_docker', docker_host.id.to_s)).to eq(27115)
      end

      it 'scopes by cloud_location' do
        other_host = create(:docker_host, start_port: 27015, ip: '10.0.0.2')
        create(:cloud_server, cloud_provider: 'remote_docker', port: '27115', cloud_status: 'ready', cloud_location: docker_host.id.to_s)
        expect(CloudServer.next_available_port_for('remote_docker', other_host.id.to_s)).to eq(27015)
      end
    end
  end

  describe '#zip_file_creator_class' do
    it 'returns DownloadThenZipFileCreator' do
      expect(subject.zip_file_creator_class).to eq(DownloadThenZipFileCreator)
    end
  end
end
