# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Group do
  describe 'validations' do
    it 'requires a name' do
      group = Group.new(name: nil)
      expect(group).not_to be_valid
      expect(group.errors[:name]).to be_present
    end
  end

  describe 'class lookup methods' do
    it 'returns the persisted, correctly named singleton groups' do
      {
        donator_group: 'Donators',
        admin_group: 'Admins',
        league_admin_group: 'League Admins',
        config_admin_group: 'Config Admins',
        streamer_group: 'Streamers',
        trusted_api_group: 'Trusted API',
        team_comtress_group: 'Team Comtress',
        cloud_group: 'Cloud'
      }.each do |method, expected_name|
        group = Group.public_send(method)
        expect(group).to be_a(Group)
        expect(group).to be_persisted
        expect(group.name).to eq(expected_name)
      end
    end

    it 'memoizes each lookup to the same object across calls' do
      expect(Group.donator_group).to equal(Group.donator_group)
      expect(Group.admin_group).to equal(Group.admin_group)
    end

    it 'points each lookup at a distinct record' do
      expect(Group.donator_group.id).not_to eq(Group.admin_group.id)
    end
  end

  describe '.private_user' do
    it 'creates a group named after the user uid the first time' do
      user = create(:user, uid: '76561197960497430')

      expect {
        @group = Group.private_user(user)
      }.to change(Group, :count).by(1)

      expect(@group.name).to eq('76561197960497430')
      expect(@group).to be_persisted
    end

    it 'returns the existing group on subsequent lookups instead of duplicating it' do
      user = create(:user, uid: '76561197960497430')
      first = Group.private_user(user)

      expect {
        second = Group.private_user(user)
        expect(second).to eq(first)
      }.not_to change(Group, :count)
    end
  end

  describe '.non_private scope' do
    it 'excludes groups whose name looks like a steamid64 (private user groups)' do
      user = create(:user, uid: '76561197960497430')
      private_group = Group.private_user(user)

      expect(Group.non_private).to include(Group.donator_group)
      expect(Group.non_private).not_to include(private_group)
    end
  end

  describe 'group_users association expiry filtering' do
    let(:group) { create(:group) }
    let(:user) { create(:user) }

    it 'includes memberships with a nil (eternal) expiry' do
      create(:group_user, group: group, user: user, expires_at: nil)

      expect(group.reload.users).to include(user)
    end

    it 'includes memberships that expire in the future' do
      create(:group_user, group: group, user: user, expires_at: 1.day.from_now)

      expect(group.reload.users).to include(user)
    end

    it 'excludes memberships that have already expired' do
      create(:group_user, group: group, user: user, expires_at: 1.day.ago)

      expect(group.reload.users).not_to include(user)
    end
  end

  describe 'servers association' do
    it 'exposes servers through group_servers' do
      group = create(:group)
      server = create(:server)
      create(:group_server, group: group, server: server)

      expect(group.reload.servers).to include(server)
    end
  end
end
