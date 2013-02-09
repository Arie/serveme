class User < ActiveRecord::Base
  devise :omniauthable

  attr_accessible :uid, :nickname, :name, :provider

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

end
