class GroupServer < ActiveRecord::Base
  belongs_to :server
  belongs_to :group
  validates_presence_of :server_id, :group_id
end
