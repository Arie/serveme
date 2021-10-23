# frozen_string_literal: true

require 'spec_helper'

describe User do
  describe '#steam_profile_url' do
    it 'creates a steam profile url based on the uid' do
      subject.stub(uid: '123')
      subject.steam_profile_url.should eql 'http://steamcommunity.com/profiles/123'
    end
  end

  describe '.find_for_steam_auth' do
    before do
      @auth = double(provider: 'steam',
                     uid: '321',
                     info: double(name: 'Kees', nickname: 'Killer'))
    end

    context 'new user' do
      it "creates and returns a new user if it can't find an existing one" do
        expect { User.find_for_steam_auth(@auth) }.to change { User.count }.from(0).to(1)
      end

      # JRuby and utf8mb4 don't play well together
      it 'cleans up crazy names when trying to create a new user' do
        @auth.stub(info: double(name: 'this.XKLL 🎂', nickname: 'this.XKLL 🎂'))
        expect { User.find_for_steam_auth(@auth) }.to change { User.count }.from(0).to(1)
      end
    end

    context 'existing user' do
      it 'returns an existing user if it could find one by uid' do
        create(:user, uid: '321')
        expect { User.find_for_steam_auth(@auth) }.not_to change { User.count }
      end

      it 'updates an existing user with new information' do
        user = create(:user, name: 'Karel', uid: '321')
        expect { User.find_for_steam_auth(@auth) }.not_to change { User.count }
        user.reload.name.should eql 'Kees'
      end

      it 'cleans up the nickname when trying to update an existing user' do
        user = create(:user, name: 'Karel', uid: '321')
        @auth.stub(uid: '321',
                   provider: 'steam',
                   info: double(name: 'this.XKLL 🎂', nickname: 'this.XKLL 🎂'))
        expect { User.find_for_steam_auth(@auth) }.not_to change { User.count }
        user.reload.name.should eql 'this.XKLL 🎂'
      end
    end
  end

  describe '#total_reservation_seconds' do
    it 'calculates the amount of time a user has reserved servers' do
      user = create(:user)
      create(:reservation, user: user, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
      user.total_reservation_seconds.should == 3600
    end
  end

  describe '#top10?' do
    it 'returns if a user is in the top 10' do
      user = create(:user)
      create(:reservation, user: user)
      user.should be_top10
    end
  end

  describe '#donator?' do
    it 'is no longer a donator if the membership expired' do
      user = create(:user)
      user.groups << Group.donator_group

      user.group_users.last.update_attribute(:expires_at, 1.day.ago)
      user.reload.should_not be_donator
    end

    it 'is a donator when the membership is eternal' do
      user = create(:user)
      user.groups << Group.donator_group

      user.group_users.last.update_attribute(:expires_at, nil)
      user.reload.should be_donator
    end

    it 'is a donator when the membership expires in future' do
      user = create(:user)
      user.groups << Group.donator_group

      user.group_users.last.update_attribute(:expires_at, 1.day.from_now)
      user.reload.should be_donator
    end
  end

  describe '#donator_until' do
    it 'knows how long it is still a donator' do
      user = create(:user)
      user.groups << Group.donator_group
      expiration = 1.day.from_now
      user.group_users.last.update_attribute(:expires_at, 1.day.from_now)
      user.donator_until.to_date.should == expiration.to_date
    end
  end

  describe '#admin?' do
    it 'is an admin when in the admin group' do
      user = create(:user)
      user.groups << Group.admin_group
      user.should be_admin
    end
  end

  describe '#league_admin?' do
    it 'is a league admin when in the league admin group' do
      user = create(:user)
      user.groups << Group.league_admin_group
      user.should be_league_admin
    end
  end
end
