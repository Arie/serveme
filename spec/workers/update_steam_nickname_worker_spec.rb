# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe UpdateSteamNicknameWorker do
  it "updates the user's name and nickname", :vcr do
    uid = '76561197960497430'
    user = create(:user, name: 'Not my nickname', uid: uid)
    UpdateSteamNicknameWorker.perform_async(uid)
    expect(user.reload.nickname).to eql 'Arie - serveme.tf'
  end

  describe '#ban_user' do
    let(:worker) { UpdateSteamNicknameWorker.new }
    let(:server) { double('server') }
    let(:steam_uid) { '76561198011511324' }

    before do
      allow(Server).to receive(:active).and_return([ server ])
    end

    it 'kicks and bans users with proper command order' do
      expect(server).to receive(:rcon_exec).with('kick [U:1:51245596] You are banned from this service')
      expect(server).to receive(:rcon_exec).with('banid 0 [U:1:51245596]')
      worker.ban_user(steam_uid)
    end
  end
end
