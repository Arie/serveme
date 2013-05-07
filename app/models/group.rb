class Group < ActiveRecord::Base
  validates_presence_of :name

  has_many :users,    :through => :group_users
  has_many :group_users

  has_many :servers,  :through => :group_servers
  has_many :group_servers

  attr_accessible :name

  def self.donator_group
    find_by_name("Donators")
  end

end
