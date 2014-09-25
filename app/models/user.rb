class User < ActiveRecord::Base
  devise :omniauthable, :rememberable, :trackable

  attr_accessible :uid, :nickname, :name, :provider, :logs_tf_api_key, :time_zone

  has_many :log_uploads, :through => :reservations
  has_many :reservations
  has_many :group_users, -> { where("group_users.expires_at IS NULL OR group_users.expires_at > ?", Time.current)}
  has_many :groups,   :through => :group_users
  has_many :servers,  :through => :groups
  has_many :paypal_orders
  has_many :reservation_players, :primary_key => :uid, :foreign_key => :steam_uid
  has_many :player_statistics,   :primary_key => :uid, :foreign_key => :steam_uid
  geocoded_by :current_sign_in_ip
  before_save :geocode, :if => :current_sign_in_ip_changed?

  def self.find_for_steam_auth(auth, signed_in_resource=nil)
    user = User.where(:provider => auth.provider, :uid => auth.uid).first
    if user
      user.update_attributes(:name => auth.info.name, :nickname => auth.info.nickname)
    else
      user = User.create(  name:      auth.info.name,
                           nickname:  auth.info.nickname,
                           provider:  auth.provider,
                           uid:       auth.uid
                         )
    end
    user
  end

  def steam_profile_url
    "http://steamcommunity.com/profiles/#{uid}"
  end

  def donator?
    @donator ||= groups.include?(Group.donator_group)
  end

  def admin?
    @admin ||= groups.include?(Group.admin_group)
  end

  def maximum_reservation_length
    if admin?
      10.hours
    elsif donator?
      5.hours
    else
      2.hours
    end
  end

  def reservation_extension_time
    if donator?
      1.hour
    else
      20.minutes
    end
  end

  def total_reservation_seconds
    reservations.to_a.sum(&:duration)
  end

  def top10?
    Statistic.top_10_users.has_key?(self)
  end

  def donator_until
    if donator?
      group_users.find_by_group_id(Group.donator_group).try(:expires_at)
    end
  end

  def has_private_server_option?
    @has_private_server_option ||=
      begin
        groups.include?(Group.private_user(self))
      end
  end

  def private_server
    Group.private_user(self).servers.first
  end

  def private_server_id=(server_id)
    if server_id.to_i > 0
      group_server = Group.private_user(self).group_servers.first_or_initialize
      group_server.server_id = server_id.to_i
      group_server.save!
    end
  end

end
