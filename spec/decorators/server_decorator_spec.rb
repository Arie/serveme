require 'spec_helper'

describe ServerDecorator do

  let(:server) { build(:server, :name => "Name") }
  subject { ServerDecorator.new(server) }

  describe "#name" do

    it "decorates the server name with a flag" do
      subject.stub(:flag => "foo")
      subject.name.should == "fooName"
    end

  end

  describe '#flag' do

    context "server with location" do

      it 'returns an empty span with the flag class' do
        location = stub(:flag => "en", :name => "England")
        server.stub(:location => location)
        subject.flag.should == '<span class="flags-en" title="England"></span>'
      end

      it 'returns an empty string' do
        server.stub(:location => nil)
        subject.flag.should == ''
      end

    end
  end

end
