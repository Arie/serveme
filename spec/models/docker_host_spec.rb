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

    it 'requires ip' do
      host = DockerHost.new(city: 'Amsterdam', location: create(:location))
      expect(host).not_to be_valid
      expect(host.errors[:ip]).to be_present
    end

    it 'requires start_port >= 27015' do
      host = build(:docker_host, start_port: 27014)
      expect(host).not_to be_valid
      expect(host.errors[:start_port]).to be_present
    end

    it 'is valid with all required attributes' do
      host = build(:docker_host)
      expect(host).to be_valid
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
