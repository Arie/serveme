require 'spec_helper'

describe Rating do

  it "requires some fields" do
    subject.valid?
    subject.should have(1).error_on(:reservation)
    subject.should have(1).error_on(:steam_uid)
    subject.should have(1).error_on(:opinion)
  end

  it "links to a user if it can find one" do
    user = create :user, :uid => "12345"
    subject.steam_uid = "12345"
    subject.user.should == user
  end

  it "knows if the rater is a donator" do
    user = create :user, :uid => "12345"
    user.groups << Group.donator_group
    subject.steam_uid = "12345"

    subject.should be_donator
  end

end
