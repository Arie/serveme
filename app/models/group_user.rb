# frozen_string_literal: true

class GroupUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :group
end
