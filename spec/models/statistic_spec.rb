require 'spec_helper'

describe Statistic do

  describe '.recent_reservations' do

    it 'orders by creation date' do
      oldest  = create :reservation, :created_at => 4.days.ago
      older   = create :reservation, :created_at => 3.days.ago
      new     = create :reservation, :created_at => 2.days.ago
      newest  = create :reservation, :created_at => 1.day.ago
      reservations = [newest, new, older, oldest]
      Statistic.recent_reservations.map(&:id).should eql reservations.map(&:id)
    end

  end

  describe '.top_10' do

    it "returns a hash with top users" do
      top_user    = create :user, :name => "Top user"
      other_user  = create :user, :name => "Not top user"

      create :reservation, :user => top_user
      create :reservation, :user => top_user, :starts_at => 24.hours.from_now, :ends_at => 25.hours.from_now
      Version.update_all(:whodunnit => top_user.id)
      create :reservation, :user => other_user
      Version.last.update_attributes(:whodunnit => other_user.id)

      top_10_hash = Statistic.top_10
      top_10_hash[top_user].should eql 2
      top_10_hash[other_user].should eql 1
    end
  end
end
