# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ServerUpdateWorker do
  let(:latest_version) { 10_828_683 }
  let(:old_version)    { 10_822_003 }

  define_method(:outdated_server) do |name, ip: 'shared.serveme.tf', port: '27015', **attrs|
    create(:server, { name: name, ip: ip, port: port, active: true, last_known_version: old_version }.merge(attrs))
  end

  before do
    allow_any_instance_of(LocalServer).to receive(:restart).and_return(true)
  end

  describe 'stale "Updating" servers' do
    it 'does not let servers stuck Updating block others on the same ip forever' do
      outdated_server('stuck #1', port: '27015', update_status: 'Updating', update_started_at: 3.days.ago)
      outdated_server('stuck #2', port: '27025', update_status: 'Updating', update_started_at: 3.days.ago)
      healthy = outdated_server('healthy', port: '27035')

      described_class.new.perform(latest_version)

      expect(healthy.reload.update_status).to eq('Updating')
    end

    it 'still respects the per-ip limit for genuinely in-flight updates' do
      outdated_server('in flight #1', port: '27015', update_status: 'Updating', update_started_at: 1.minute.ago)
      outdated_server('in flight #2', port: '27025', update_status: 'Updating', update_started_at: 1.minute.ago)
      waiting = outdated_server('waiting', port: '27035')

      described_class.new.perform(latest_version)

      expect(waiting.reload.update_status).to be_nil
    end

    it 'treats a NULL update_started_at as stale rather than blocking forever' do
      outdated_server('no timestamp #1', port: '27015', update_status: 'Updating', update_started_at: nil)
      outdated_server('no timestamp #2', port: '27025', update_status: 'Updating', update_started_at: nil)
      healthy = outdated_server('healthy', port: '27035')

      described_class.new.perform(latest_version)

      expect(healthy.reload.update_status).to eq('Updating')
    end

    it 'spends limited slots on never-tried servers before retrying stale ones' do
      stale = outdated_server('stale', port: '27015', update_status: 'Updating', update_started_at: 3.days.ago)
      fresh_a = outdated_server('fresh a', port: '27025')
      fresh_b = outdated_server('fresh b', port: '27035')

      described_class.new.perform(latest_version)

      expect([ fresh_a, fresh_b ].map { |s| s.reload.update_status }).to eq(%w[Updating Updating])
      expect(stale.reload.update_started_at).to be < described_class::STALE_UPDATE_TIMEOUT.ago
    end

    it 'retries a stale server and re-stamps update_started_at so it backs off again' do
      stale = outdated_server('stale', port: '27015', update_status: 'Updating', update_started_at: 3.days.ago)

      described_class.new.perform(latest_version)

      expect(stale.reload.update_started_at).to be > described_class::STALE_UPDATE_TIMEOUT.ago
    end
  end

  describe 'normal behaviour' do
    it 'restarts an outdated server and marks it Updating' do
      server = outdated_server('outdated')

      described_class.new.perform(latest_version)

      expect(server.reload.update_status).to eq('Updating')
      expect(server.reload.update_started_at).not_to be_nil
    end

    it 'leaves reserved servers alone' do
      server = outdated_server('reserved')
      create(:reservation, server: server, starts_at: 1.minute.ago, ends_at: 1.hour.from_now)

      described_class.new.perform(latest_version)

      expect(server.reload.update_status).to be_nil
    end

    it 'counts the per-ip limit independently for different ips' do
      outdated_server('a1', ip: 'a.serveme.tf', port: '27015', update_status: 'Updating', update_started_at: 1.minute.ago)
      outdated_server('a2', ip: 'a.serveme.tf', port: '27025', update_status: 'Updating', update_started_at: 1.minute.ago)
      other_host = outdated_server('b1', ip: 'b.serveme.tf', port: '27015')

      described_class.new.perform(latest_version)

      expect(other_host.reload.update_status).to eq('Updating')
    end
  end
end
