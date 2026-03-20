# typed: strict
# frozen_string_literal: true

class Group < ActiveRecord::Base
  extend T::Sig

  DONATOR_GROUP = T.let(find_or_create_by(name: "Donators"), Group)
  ADMIN_GROUP = T.let(find_or_create_by(name: "Admins"), Group)
  LEAGUE_ADMIN_GROUP = T.let(find_or_create_by(name: "League Admins"), Group)
  CONFIG_ADMIN_GROUP = T.let(find_or_create_by(name: "Config Admins"), Group)
  STREAMER_GROUP = T.let(find_or_create_by(name: "Streamers"), Group)
  TEAM_COMTRESS_GROUP = T.let(find_or_create_by(name: "Team Comtress"), Group)
  TRUSTED_API_GROUP = T.let(find_or_create_by(name: "Trusted API"), Group)
  CLOUD_GROUP = T.let(find_or_create_by(name: "Cloud"), Group)

  validates_presence_of :name

  has_many :group_users, -> { where(expires_at: nil).or(where(expires_at: Time.current..)) }, dependent: :destroy
  has_many :users, through: :group_users
  has_many :group_servers, dependent: :destroy
  has_many :servers, through: :group_servers

  scope :non_private, -> { where("name NOT LIKE '7656%'") }

  sig { returns(Group) }
  def self.donator_group
    DONATOR_GROUP
  end

  sig { returns(Group) }
  def self.admin_group
    ADMIN_GROUP
  end

  sig { returns(Group) }
  def self.league_admin_group
    LEAGUE_ADMIN_GROUP
  end

  sig { returns(Group) }
  def self.config_admin_group
    CONFIG_ADMIN_GROUP
  end

  sig { returns(Group) }
  def self.streamer_group
    STREAMER_GROUP
  end

  sig { returns(Group) }
  def self.trusted_api_group
    TRUSTED_API_GROUP
  end

  sig { returns(Group) }
  def self.team_comtress_group
    TEAM_COMTRESS_GROUP
  end

  sig { returns(Group) }
  def self.cloud_group
    CLOUD_GROUP
  end

  sig { params(user: User).returns(Group) }
  def self.private_user(user)
    where(name: user.uid).first_or_create!
  end
end
