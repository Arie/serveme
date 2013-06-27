class Version < ActiveRecord::Base
  attr_accessible :event, :whodunnit, :object, :item_id, :item_type
end
