require 'spec_helper'

describe Product do

  it { should have_many(:paypal_orders) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:price) }

  describe "#list_name" do
    it "is a name with the rounded price included for use in the dropdown" do

      subject.name = "foobar"
      subject.price = 12.34
      subject.list_name.should == "foobar - 12 EUR"
    end
  end
end
