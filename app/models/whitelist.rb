class Whitelist < ActiveRecord::Base
  attr_accessible :file
  has_many :reservations, :dependent => :nullify

  def to_s
    file
  end

end
