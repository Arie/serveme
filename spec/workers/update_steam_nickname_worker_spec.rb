require 'spec_helper'

describe UpdateSteamNicknameWorker do

  it "updates the user's name and nickname", :vcr do
    uid = "76561197960497430"
    user = create(:user, name: "Not my nickname", uid: uid)
    UpdateSteamNicknameWorker.perform_async(uid)
    expect(user.reload.nickname).to eql "Arie - serveme.tf"
  end
end
