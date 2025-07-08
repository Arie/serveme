# typed: true
# frozen_string_literal: true

class PrivateServerCleanupWorker
  include Sidekiq::Worker

  def perform
    expired_private_servers.destroy_all
  end

  def expired_private_servers
    GroupServer.where(group: expired_private_groups)
  end

  def expired_private_groups
    Group.where(id: expired_private_group_ids)
  end

  def expired_private_group_ids
    GroupUser
      .joins(:group)
      .where(expires_at: 2.days.ago...Time.current)
      .where.not(groups: { name: "Donators" })
      .pluck(:group_id)
  end
end
