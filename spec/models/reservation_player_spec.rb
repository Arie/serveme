require 'spec_helper'

describe ReservationPlayer do
  context 'banned asns' do
    it 'doesnt flag good ASNs' do
      good_ip = '1.128.0.1'
      expect(described_class.banned_asn?(good_ip)).to be false
    end

    it 'recognizes bad ASNs' do
      described_class.stub(:custom_banned_asns).and_return([1221])
      expect(described_class.banned_asn?('1.128.0.1')).to be true
    end
  end
end
