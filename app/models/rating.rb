class Rating < ActiveRecord::Base

  belongs_to :reservation

  validates_presence_of :reservation, :steam_uid, :opinion

  def parse_message!(message)
    #!rate bad lag during midfights
    message = message.split(" ")
    self[:opinion] = message[1]
    self[:reason] = message[2..-1].join(" ")
    save!
  end

end
