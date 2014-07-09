class PrivateServer

  include ActiveModel::Model

  attr_accessor :server_id

  validates_presence_of :server_id


end
