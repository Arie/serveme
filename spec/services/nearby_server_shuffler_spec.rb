# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe NearbyServerShuffler do
  let(:chicago) { { latitude: 41.87, longitude: -87.65 } }
  let(:dallas) { { latitude: 32.78, longitude: -96.80 } }

  # after_validation geocoding overwrites coordinates passed to create
  define_method(:at) do |record, coords|
    record.tap { |r| r.update_columns(coords) }
  end

  it 'keeps far-away groups in their original order' do
    chi = at(create(:docker_host, hostname: 'chi1.serveme.tf'), chicago)
    dal = at(create(:docker_host, hostname: 'dal.serveme.tf'), dallas)

    20.times { expect(described_class.shuffle([ chi, dal ])).to eq([ chi, dal ]) }
  end

  it 'puts every nearby machine first some of the time' do
    bare = Array.new(4) { |i| at(create(:server, ip: 'chi1.serveme.tf', port: (27015 + (i * 10)).to_s), chicago) }
    chi1 = at(create(:docker_host, hostname: 'chi1.serveme.tf'), chicago)
    chi2 = at(create(:docker_host, hostname: 'chi2.serveme.tf'), chicago)
    chi3 = at(create(:docker_host, hostname: 'chi3.serveme.tf'), chicago)

    firsts = Array.new(60) { described_class.machine(described_class.shuffle(bare + [ chi1, chi2, chi3 ]).first) }

    expect(firsts.uniq).to contain_exactly('chi1.serveme.tf', 'chi2.serveme.tf', 'chi3.serveme.tf')
  end

  it 'keeps entries of one machine together' do
    bare = Array.new(2) { |i| at(create(:server, ip: 'chi1.serveme.tf', port: (27015 + (i * 10)).to_s), chicago) }
    chi1 = at(create(:docker_host, hostname: 'chi1.serveme.tf'), chicago)
    chi2 = at(create(:docker_host, hostname: 'chi2.serveme.tf'), chicago)

    machines = described_class.shuffle(bare + [ chi1, chi2 ]).map { |c| described_class.machine(c) }

    expect(machines.chunk_while { |a, b| a == b }.map(&:first)).to contain_exactly('chi1.serveme.tf', 'chi2.serveme.tf')
  end

  it 'does not group candidates without coordinates' do
    a = at(create(:server, ip: '1.1.1.1'), latitude: nil, longitude: nil)
    b = at(create(:server, ip: '2.2.2.2'), latitude: nil, longitude: nil)

    20.times { expect(described_class.shuffle([ a, b ])).to eq([ a, b ]) }
  end
end
