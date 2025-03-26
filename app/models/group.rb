# typed: strict
# frozen_string_literal: true

class Group < ActiveRecord::Base
  extend T::Sig

  DONATOR_GROUP = T.let(find_or_create_by(name: "Donators"), Group)
  ADMIN_GROUP = T.let(find_or_create_by(name: "Admins"), Group)
  LEAGUE_ADMIN_GROUP = T.let(find_or_create_by(name: "League Admins"), Group)
  STREAMER_GROUP = T.let(find_or_create_by(name: "Streamers"), Group)

  validates_presence_of :name

  has_many :group_users, -> { where("group_users.expires_at IS NULL OR group_users.expires_at > ?", Time.current) }, dependent: :destroy
  has_many :users, through: :group_users
  has_many :group_servers, dependent: :destroy
  has_many :servers, through: :group_servers

  sig { returns(Group) }
  def self.donator_group
    find_or_create_by(name: "Donators")
  end

  sig { returns(Group) }
  def self.admin_group
    find_or_create_by(name: "Admins")
  end

  sig { returns(Group) }
  def self.league_admin_group
    find_or_create_by(name: "League Admins")
  end

  sig { returns(Group) }
  def self.streamer_group
    find_or_create_by(name: "Streamers")
  end

  sig { returns(Group) }
  def self.trusted_api_group
    find_or_create_by(name: "Trusted API")
  end

  sig { params(user: User).returns(Group) }
  def self.private_user(user)
    where(name: user.uid).first_or_create!
  end
end
