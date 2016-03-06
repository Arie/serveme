require 'spec_helper'

describe LogScanWorker do

  it "finds the logs for a reservation" do
    Dir.should_receive(:glob).with(Rails.root.join("server_logs/1/*.log")).and_return([])
    LogScanWorker.perform_async(1)
  end

  it "loops over the found log and finds the players in each one" do
    Dir.should_receive(:glob).with(Rails.root.join("server_logs/1/*.log")).and_return([Rails.root.join("spec", "fixtures", "logs", "special_characters.log")])

    LogScanWorker.perform_async(1)
    ReservationPlayer.count.should == 13
    ReservationPlayer.pluck(:steam_uid).sort.should == ["76561197960497430", "76561197970773724", "76561197978390640", "76561197979088829", "76561197986034945", "76561197991033579", "76561197991320838", "76561197993843145", "76561197994754935", "76561198012531702", "76561198030042478", "76561198043711148", "76561198054664886"].sort
  end

end
