require 'spec_helper'

describe MapUpload do

  it "requires a user" do
    subject.valid?
    subject.should have(1).error_on(:user_id)
  end

end
