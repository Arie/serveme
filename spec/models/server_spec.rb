# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Server do
  describe '#rcon_say' do
    let(:server) { create(:server) }

    before do
      allow(server).to receive(:rcon_exec).and_return("ok")
    end

    it 'splits long messages at word boundaries' do
      long_message = "Welcome to our TF2 server! We're playing some competitive 6v6 matches today. Please make sure to follow the server rules: no cheating, be respectful to other players, communicate with your team, and most importantly have fun! If you need any help just ask an admin. Good luck and have fun everyone! Remember to join our Discord server for announcements and to find other players to queue with."
      expect(server).to receive(:rcon_exec).with("say Welcome to our TF2 server! We're playing some competitive 6v6 matches today. Please make sure to follow the server rules: no cheating, be respectful to other players, communicate with your team, and").ordered
      expect(server).to receive(:rcon_exec).with("say most importantly have fun! If you need any help just ask an admin. Good luck and have fun everyone! Remember to join our Discord server for announcements and to find other players to queue with.").ordered
      server.rcon_say(long_message)
    end

    it 'handles multiline messages' do
      multiline = "First line with some rules\nSecond line explaining more\nThird line with a conclusion"
      expect(server).to receive(:rcon_exec).with("say First line with some rules").ordered
      expect(server).to receive(:rcon_exec).with("say Second line explaining more").ordered
      expect(server).to receive(:rcon_exec).with("say Third line with a conclusion").ordered
      server.rcon_say(multiline)
    end

    it 'handles long multiline messages' do
      multiline = [
        "Welcome to our TF2 server! We're playing some competitive 6v6 matches today. Please make sure to follow the server rules: no cheating, be respectful to other players, communicate with your team, and most importantly have fun!",
        "If you need any help just ask an admin. Good luck and have fun everyone! Remember to join our Discord server for announcements and to find other players to queue with."
      ].join("\n")
      expect(server).to receive(:rcon_exec).with("say Welcome to our TF2 server! We're playing some competitive 6v6 matches today. Please make sure to follow the server rules: no cheating, be respectful to other players, communicate with your team, and").ordered
      expect(server).to receive(:rcon_exec).with("say most importantly have fun!").ordered
      expect(server).to receive(:rcon_exec).with("say If you need any help just ask an admin. Good luck and have fun everyone! Remember to join our Discord server for announcements and to find other players to queue with.").ordered
      server.rcon_say(multiline)
    end
  end

  describe '#save_version_info' do
    let(:server) { create(:server, update_status: 'Updating', update_started_at: Time.current) }
    let(:server_info) { double('ServerInfo') }

    before do
      allow(Server).to receive(:latest_version).and_return(100)
      allow(server_info).to receive(:version)
    end

    context 'when version is nil' do
      before { allow(server_info).to receive(:version).and_return(nil) }

      it 'returns early without updating to prevent incorrect version comparison' do
        expect(server).not_to receive(:update)
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updating') # Status remains unchanged
        expect(server.last_known_version).to be_nil
      end
    end

    context 'when version is older than latest' do
      before { allow(server_info).to receive(:version).and_return(90) }

      it 'marks server as outdated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Outdated')
        expect(server.last_known_version).to eq(90)
      end
    end

    context 'when version is equal to latest' do
      before { allow(server_info).to receive(:version).and_return(100) }

      it 'marks server as updated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updated')
        expect(server.last_known_version).to eq(100)
      end
    end

    context 'when version is newer than latest' do
      before { allow(server_info).to receive(:version).and_return(110) }

      it 'marks server as updated' do
        server.save_version_info(server_info)
        expect(server.reload.update_status).to eq('Updated')
        expect(server.last_known_version).to eq(110)
      end
    end
  end

  describe '#rcon_exec' do
    let(:server) { create(:server, rcon: 'secret') }

    before do
      allow(server).to receive(:condenser).and_return(double('condenser'))
      allow(server.condenser).to receive(:rcon_auth).and_return(true)
      allow(server.condenser).to receive(:rcon_exec).and_return("ok")
    end

    it 'escapes double slashes in commands to prevent Source engine parsing issues' do
      command = 'say Visit https://steamcommunity.com/ and https://etf2l.org/ for more info'
      escaped_command = 'say Visit https:/​/steamcommunity.com/ and https:/​/etf2l.org/ for more info'

      expect(server.condenser).to receive(:rcon_exec).with(escaped_command)
      server.rcon_exec(command)
    end
  end
end
