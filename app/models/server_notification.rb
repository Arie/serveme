# frozen_string_literal: true
class ServerNotification < ActiveRecord::Base

  def self.for_everyone
    where(:notification_type => 'public')
  end

  def self.ads
    where(:notification_type => 'ad')
  end

end
