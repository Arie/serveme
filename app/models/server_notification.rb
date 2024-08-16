# typed: strict
# frozen_string_literal: true

class ServerNotification < ActiveRecord::Base
  extend T::Sig

  sig { returns(ActiveRecord::Relation) }
  def self.for_everyone
    where(notification_type: 'public')
  end

  sig { returns(ActiveRecord::Relation) }
  def self.ads
    where(notification_type: 'ad')
  end
end
