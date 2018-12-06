# frozen_string_literal: true
class Group < ActiveRecord::Base

  DONATOR_GROUP  = find_or_create_by(:name => "Donators")
  ADMIN_GROUP    = find_or_create_by(:name => "Admins")
  STREAMER_GROUP = find_or_create_by(:name => "Streamers")

  validates_presence_of :name

  has_many :group_users, -> { where("group_users.expires_at IS NULL OR group_users.expires_at > ?", Time.current)}, :dependent => :destroy
  has_many :users, through: :group_users

  has_many :group_servers, :dependent => :destroy
  has_many :servers, through: :group_servers

  def self.donator_group
    DONATOR_GROUP
  end

  def self.admin_group
    ADMIN_GROUP
  end

  def self.streamer_group
    STREAMER_GROUP
  end

  def self.private_user(user)
    where(:name => user.uid).first_or_create!
  end

end
