# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe DockerHost do
  describe 'validations' do
    it 'requires city' do
      host = DockerHost.new(ip: '10.0.0.1', location: create(:location))
      expect(host).not_to be_valid
      expect(host.errors[:city]).to be_present
    end

    it 'requires ip for non-provider hosts' do
      host = DockerHost.new(city: 'Amsterdam', hostname: 'test.serveme.tf', location: create(:location))
      expect(host).not_to be_valid
      expect(host.errors[:ip]).to be_present
    end

    it 'does not require ip for provider hosts' do
      host = build(:docker_host, ip: nil, provider: 'hetzner', provider_location: 'fsn1')
      expect(host).to be_valid
    end

    it 'requires provider_location when provider is set' do
      host = build(:docker_host, provider: 'hetzner', provider_location: nil)
      expect(host).not_to be_valid
      expect(host.errors[:provider_location]).to be_present
    end

    it 'validates provider inclusion' do
      host = build(:docker_host, provider: 'invalid')
      expect(host).not_to be_valid
      expect(host.errors[:provider]).to be_present
    end

    it 'requires start_port >= 27015' do
      host = build(:docker_host, start_port: 27014)
      expect(host).not_to be_valid
      expect(host.errors[:start_port]).to be_present
    end

    it 'requires hostname' do
      host = build(:docker_host, hostname: nil)
      expect(host).not_to be_valid
      expect(host.errors[:hostname]).to be_present
    end

    it 'requires unique hostname' do
      create(:docker_host, hostname: 'de1.serveme.tf')
      host = build(:docker_host, hostname: 'de1.serveme.tf', ip: '10.0.0.2')
      expect(host).not_to be_valid
      expect(host.errors[:hostname]).to be_present
    end

    it 'is valid with all required attributes' do
      host = build(:docker_host)
      expect(host).to be_valid
    end
  end

  describe '#serveme_hostname?' do
    it 'returns true for serveme.tf hostnames' do
      host = build(:docker_host, hostname: 'de1.serveme.tf')
      expect(host.serveme_hostname?).to be true
    end

    it 'returns true for regional serveme.tf hostnames' do
      host = build(:docker_host, hostname: 'us1.na.serveme.tf')
      expect(host.serveme_hostname?).to be true
    end

    it 'returns false for other hostnames' do
      host = build(:docker_host, hostname: 'server1.example.com')
      expect(host.serveme_hostname?).to be false
    end
  end

  describe '#setup_status' do
    it 'defaults to pending' do
      host = create(:docker_host)
      expect(host.setup_status).to eq('pending')
    end
  end

  describe '.active' do
    it 'returns only active hosts' do
      active = create(:docker_host, active: true)
      create(:docker_host, active: false, ip: '10.0.0.2')
      expect(DockerHost.active).to eq([ active ])
    end
  end

  describe '#location' do
    it 'belongs to a location' do
      host = create(:docker_host)
      expect(host.location).to be_a(Location)
    end
  end
end
