# typed: true
# frozen_string_literal: true

class AddGroupMembership
  extend T::Sig

  attr_accessor :duration, :user, :group

  sig { params(days: T.untyped, user: User, group: Group).void }
  def initialize(days, user, group = Group.donator_group)
    @duration = days.days
    @user     = user
    @group    = group
  end

  sig { void }
  def perform
    group_membership.expires_at = new_expiration_time
    group_membership.save!
  end

  sig { returns(T.nilable(ActiveSupport::TimeWithZone)) }
  def new_expiration_time
    # Refuse setting expiration time for existing eternal memberships
    return nil if group_membership.expires_at.nil? && !group_membership.new_record?

    if first_time_member? || former_member?
      duration.from_now
    else
      T.must(group_membership.expires_at) + duration
    end
  end

  sig { returns(GroupUser) }
  def group_membership
    @group_membership ||= user.group_users.where(group_id: group).first_or_initialize
  end

  sig { returns(T::Boolean) }
  def first_time_member?
    group_membership.new_record?
  end

  sig { returns(T::Boolean) }
  def former_member?
    expires_at = group_membership.expires_at
    return false if expires_at.nil?

    expires_at < Time.current
  end
end
