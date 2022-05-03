require 'spec_helper'

describe ReservationPlayer do
  context 'banned asns' do
    it 'recognizes bad ASNs' do
      ['87.249.134.16', '91.245.254.68'].each do |vpn_ip|
        expect(described_class.banned_asn?(vpn_ip)).to be true
      end
    end

    it 'doesnt flag good ASNs' do
      good_ip = '213.46.237.24'
      expect(described_class.banned_asn?(good_ip)).to be false
    end
  end
end
