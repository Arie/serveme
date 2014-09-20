class Rating < ActiveRecord::Base

  belongs_to :reservation
  belongs_to :user, :foreign_key => :steam_uid, :primary_key => :uid

  validates_presence_of :reservation, :steam_uid, :opinion

  delegate :server, :to => :reservation, :prefix => false
  delegate :name,   :to => :server, :prefix => true
  delegate :donator?, :to => :user, :prefix => false, :allow_nil => true

  def parse_message!(message)
    #!rate bad lag during midfights
    self[:opinion] = message[1]
    self[:reason] = message[2..-1].join(" ")
    save!
  end

  def publish!
    self[:published] = true
    save!
  end

  def unpublish!
    self[:published] = false
    save!
  end

  def self.published
    where(:published => true)
  end

  def self.good
    with_opinion("good")
  end

  def self.bad
    with_opinion("bad")
  end

  def self.with_opinion(opinion)
    where(:opinion => opinion)
  end

end
