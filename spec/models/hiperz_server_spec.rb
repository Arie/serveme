require 'spec_helper'

describe HiperzServer do

  describe '#restart' do

    it "visits the Hiperz restart URL", :vcr do
      subject.stub(:hiperz_id => 3873)

      subject.restart
    end

  end

  describe "#tv_port" do

    it "knows hiperz STV is +1 from gameserver port" do
      subject.stub(:port => 5)
      expect(subject.tv_port).to eql(6)
    end

  end

  describe "#ftp_connection_pool_size" do

    it "has a smaller connection pool size because the FTP server won't accept more" do
      subject.ftp_connection_pool_size.should eql 1
    end
  end

end
