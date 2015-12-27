# frozen_string_literal: true
class GroupUser < ActiveRecord::Base

  attr_accessible :user_id, :group_id, :expires_at

  belongs_to :user
  belongs_to :group

end
