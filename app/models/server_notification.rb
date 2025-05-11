# typed: strict
# frozen_string_literal: true

class ServerNotification < ActiveRecord::Base
  extend T::Sig

  validates :message, presence: true
  validates :notification_type, presence: true

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.for_everyone
    where(notification_type: "public")
  end

  sig { returns(T.any(ActiveRecord::Relation, ActiveRecord::Associations::CollectionProxy)) }
  def self.ads
    where(notification_type: "ad")
  end
end
