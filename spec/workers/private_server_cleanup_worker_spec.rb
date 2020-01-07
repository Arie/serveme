# frozen_string_literal: true

require 'spec_helper'

describe PrivateServerCleanupWorker do
  let!(:old_group)                  { create :group,        name: 'Old' }
  let!(:old_private_group_user)     { create :group_user,   group: old_group, expires_at: 1.hour.ago }
  let!(:old_private_server)         { create :server }
  let!(:old_private_group_server)   { create :group_server, group: old_group, server: old_private_server }

  let!(:young_group)                { create :group,        name: 'Young' }
  let!(:young_private_group_user)   { create :group_user,   group: young_group, expires_at: 1.month.from_now }
  let!(:young_private_server)       { create :server }
  let!(:young_private_group_server) { create :group_server, group: young_group, server: young_private_server }

  it 'finds the expired groups' do
    subject.expired_private_groups.should == [old_group]
  end

  it 'finds the expired servers for these groups' do
    subject.expired_private_servers.should == [old_private_group_server]
  end

  it 'deletes private server link for these expired groups' do
    GroupServer.count.should == 2
    PrivateServerCleanupWorker.perform_async
    GroupServer.count.should == 1
  end
end
