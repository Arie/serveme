# typed: false

require 'spec_helper'

RSpec.describe AiCommandHandler do
  let(:user) { create :user, uid: '76561197960497430' }
  let(:server) { create(:server) }
  let(:condenser) { double.as_null_object }
  let(:reservation) { create :reservation, user: user, server: server }
  let(:handler) { described_class.new(reservation) }

  before do
    allow(server).to receive(:condenser).and_return(condenser)
    allow(server).to receive(:rcon_auth).and_return(true)
    status = %Q|
    hostname: serveme.tf #1475942
    version : 9543365/24 9543365 secure
    udp/ip  : 0.0.0.0:50920  (local: 0.0.0.0:27025)  (public IP from Steam: 0.0.0.0)
    steamid : [A:1:3406007314:44672] (90263860732464146)
    account : not logged in  (No account specified)
    map     : cp_gullywash_f9 at: 0 x, 0 y, 0 z
    tags    : cp,nocrits
    sourcetv:  0.0.0.0:50920, delay 90.0s  (local: 0.0.0.0:27030)
    players : 1 humans, 1 bots (25 max)
    edicts  : 560 used of 2048 max
    # userid name                uniqueid            connected ping loss state  adr
    #      2 "SourceTV"          BOT                                     active
    #      7 "Arie - serveme.tf" [U:1:231702]        03:22       35    0 active 0.0.0.0:27005|
    allow(handler).to receive(:server_status).and_return(status)
  end

  describe '#process_request' do
    context 'when changing map' do
      let(:openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => response_content
              }
            }
          ]
        }
      end

      let(:response_content) do
        {
          command: "changelevel cp_process",
          response: "Changing map to cp_process",
          success: true
        }.to_json
      end

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
      end

      it 'executes the command and sends response' do
        expect(server).to receive(:rcon_exec).with("changelevel cp_process")
        expect(server).to receive(:rcon_say).with("Changing map to cp_process")

        result = handler.process_request("change map to process")
        expect(result["success"]).to be true
      end
    end

    context 'when loading config' do
      let(:openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => response_content
              }
            }
          ]
        }
      end

      let(:response_content) do
        {
          command: "exec etf2l_6v6",
          response: "Loading ETF2L 6v6 config",
          success: true
        }.to_json
      end

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
      end

      it 'executes the config and sends response' do
        expect(server).to receive(:rcon_exec).with("exec etf2l_6v6")
        expect(server).to receive(:rcon_say).with("Loading ETF2L 6v6 config")

        result = handler.process_request("load etf2l 6v6 config")
        expect(result["success"]).to be true
      end
    end

    context 'when setting whitelist' do
      let(:openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => response_content
              }
            }
          ]
        }
      end

      let(:response_content) do
        {
          command: "tftrue_whitelist_id etf2l_whitelist_6v6",
          response: "Setting whitelist to ETF2L 6v6",
          success: true
        }.to_json
      end

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
      end

      it 'sets the whitelist and sends response' do
        expect(server).to receive(:rcon_exec).with("tftrue_whitelist_id etf2l_whitelist_6v6")
        expect(server).to receive(:rcon_say).with("Setting whitelist to ETF2L 6v6")

        result = handler.process_request("set whitelist to etf2l 6v6")
        expect(result["success"]).to be true
      end
    end

    context 'when request is unclear' do
      let(:openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => response_content
              }
            }
          ]
        }
      end

      let(:response_content) do
        {
          command: nil,
          response: "I don't understand what you want to do. Please be more specific.",
          success: false
        }.to_json
      end

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
      end

      it 'sends error response without executing command' do
        allow(server).to receive(:rcon_exec).with("status")
        expect(server).to receive(:rcon_say).with("I don't understand what you want to do. Please be more specific.")

        result = handler.process_request("do something cool")
        expect(result["success"]).to be false
      end
    end
  end
end
