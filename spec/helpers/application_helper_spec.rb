require_relative '../../app/helpers/application_helper.rb'
require 'rspec'

class DummyClass
end

describe ApplicationHelper do

  before(:each) do
    @helper = DummyClass.new
    @helper.extend(ApplicationHelper)
  end

  describe "#just_after_midnight" do

    it "should return true when it's between 00:00 and 3:00" do

      before_midnight = Time.new(2012, 12, 12, 23, 59)
      @helper.just_after_midnight?(before_midnight).should == false

      just_after_midnight = Time.new(2012, 12, 13, 0, 1)
      @helper.just_after_midnight?(just_after_midnight).should == true

      one_am = Time.new(2012, 12, 13, 1, 0)
      @helper.just_after_midnight?(one_am).should == true

      two_am = Time.new(2012, 12, 13, 2, 00)
      @helper.just_after_midnight?(two_am).should == true

      two_five_nine_am = Time.new(2012, 12, 13, 2, 59)
      @helper.just_after_midnight?(two_five_nine_am).should == true

      three_am = Time.new(2012, 12, 13, 3, 00)
      @helper.just_after_midnight?(three_am).should == false
    end

  end
end
