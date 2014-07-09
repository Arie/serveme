class PrivateServerCleanupWorker
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  recurrence { daily.hour_of_day(5, 11, 17, 23) }

  def perform
    expired_private_servers.destroy_all
  end

  def expired_private_servers
    GroupServer.where(:group => expired_private_groups)
  end

  def expired_private_groups
    Group.where(:id => expired_private_group_ids)
  end

  def expired_private_group_ids
    GroupUser.
      joins(:group).
      where('group_users.expires_at < ? AND group_users.expires_at > ?', Time.current, 2.days.ago).
      where('groups.name != ?', "Donators").
      pluck(:group_id)
  end

end
