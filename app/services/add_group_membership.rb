class AddGroupMembership

  attr_accessor :duration, :user, :group

  def initialize(days, user, group = Group.donator_group)
    @duration = days.days
    @user     = user
    @group    = group
  end

  def perform
    group_membership.expires_at = new_expiration_time
    group_membership.save!
  end

  def new_expiration_time
    if first_time_member? || former_member?
      duration.from_now
    else
      group_membership.expires_at + duration
    end
  end

  def group_membership
    @group_membership ||= user.group_users.where(:group_id => group).first_or_initialize
  end

  def first_time_member?
    group_membership.new_record?
  end

  def former_member?
    group_membership.expires_at < Time.current
  end

end

