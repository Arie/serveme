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

    it 'knows SDR ips wont be in the ASN database, so should just return false for those' do
      expect(described_class.banned_asn?('169.254.1.1')).to be false
    end
  end

  context 'banned steam ids' do
    it 'recognizes a banned steam id' do
      expect(described_class.banned_uid?(76561198310925535)).to be true
    end
    it 'doesnt flag a good steam id as banned' do
      expect(described_class.banned_uid?(76561197960497430)).to be false
    end
  end

  context 'whitelisted steam id' do
    it 'recognizes a whitelisted steam id' do
      expect(described_class.whitelisted_uid?(76561198350261670)).to be true
    end

    it 'doesnt flag an unknown steam id as whitelisted' do
      expect(described_class.whitelisted_uid?('foobarwidget')).to be false
    end
  end

  context 'banned ip' do
    it 'recognizes a banned ip in a range' do
      expect(described_class.banned_ip?('176.40.96.1')).to be true
    end
    it 'doesnt flag a good ip as banned' do
      expect(described_class.banned_ip?('127.0.0.1')).to be false
    end
  end
end
