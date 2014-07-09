require 'spec_helper'

describe AddGroupMembership do

  subject { described_class.new(31, create(:user)) }
  describe "#update_group_membership" do

    it "adds extra days to the donator status expiration date" do
      old_expires_at = 1.week.from_now
      number_of_days = 31
      group_membership = double(:new_record? => false, :expires_at => old_expires_at)
      subject.stub(:duration => number_of_days.days)
      subject.stub(:group_membership => group_membership)

      new_expires_at = old_expires_at + number_of_days.days
      group_membership.should_receive(:expires_at=).with(new_expires_at)
      group_membership.should_receive(:save!)

      subject.perform
    end

  end

  context "membership status" do

    it "should know a first time donator" do
      group_membership = double(:new_record? => true)
      subject.stub(:group_membership => group_membership)
      subject.should be_first_time_member
    end

    it "should know a former donator" do
      group_membership = double(:expires_at => 1.day.ago)
      subject.stub(:group_membership => group_membership)
      subject.should be_former_member
    end
  end


end

