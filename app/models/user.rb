class User < ActiveRecord::Base
  devise :omniauthable, :rememberable, :trackable

  attr_accessible :uid, :nickname, :name, :provider, :logs_tf_api_key, :time_zone

  has_many :log_uploads, :through => :reservations
  has_many :reservations
  has_many :group_users
  has_many :groups,   :through => :group_users
  has_many :servers,  :through => :groups

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

  def maximum_reservation_length
    if donator?
      5.hours
    else
      3.hours
    end
  end

  def total_reservation_seconds
    reservations.sum(&:duration)
  end

  def top10?
    Statistic.top_10_users.has_key?(self)
  end

end
