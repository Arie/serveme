# typed: false

require 'spec_helper'
require 'set'

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

    allow(Rails.cache).to receive(:read).and_return(nil)
    allow(Rails.cache).to receive(:write)
  end

  describe '#process_request' do
    let(:openai_response) do
      {
        "choices" => [
          {
            "message" => {
              "content" => nil,
              "tool_calls" => [
                {
                  "id" => "call_123",
                  "type" => "function",
                  "function" => {
                    "name" => "submit_server_action",
                    "arguments" => response_content
                  }
                }
              ]
            }
          }
        ]
      }
    end

    context 'when changing map' do
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

    context 'when AI returns a valid command' do
      let(:response_content) do
        {
          command: "mp_timelimit 30",
          response: "Setting timelimit to 30",
          success: true
        }.to_json
      end

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
      end

      it 'validates and executes the command' do
        expect(server).to receive(:rcon_exec).with("mp_timelimit 30")
        expect(server).to receive(:rcon_say).with("Setting timelimit to 30")
        expect(Rails.cache).to receive(:write).with(/ai_context_history/, anything, expires_in: 1.hour)

        result = handler.process_request("set timelimit to 30")
        expect(result["success"]).to be true
        expect(result["command"]).to eq("mp_timelimit 30")
      end
    end

    context 'when AI returns an invalid command' do
      let(:response_content) do
        {
          command: "xyz_invalid_command_abc",
          response: "Attempting invalid thing",
          success: true
        }.to_json
      end

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
      end

      it 'validates, logs error, sends override message, and does not execute command' do
        expect(Rails.logger).to receive(:error).with(include("Proposed disallowed command:"))
        expect(server).not_to receive(:rcon_exec)
        expect(server).to receive(:rcon_say).with("Sorry, I can't run that command as parts of it might not be allowed.")
        expect(Rails.cache).not_to receive(:write)

        result = handler.process_request("do invalid thing")
        expect(result["success"]).to be false
        expect(result["command"]).to be_nil
        expect(result["response"]).to eq("Sorry, I can't run that command as parts of it might not be allowed.")
      end
    end

    context 'when AI returns multiple commands, one invalid' do
      let(:command_string) { "mp_timelimit 60; xyz_invalid_command_abc; changelevel cp_process" }
      let(:response_content) do
        {
          command: command_string,
          response: "Doing valid and invalid things",
          success: true
        }.to_json
      end

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
      end

      it 'validates the full string, logs error, sends override message, and does not execute' do
        expect(Rails.logger).to receive(:error).with(include("Proposed disallowed command:"))
        expect(server).not_to receive(:rcon_exec)
        expect(server).to receive(:rcon_say).with("Sorry, I can't run that command as parts of it might not be allowed.")
        expect(Rails.cache).not_to receive(:write)

        result = handler.process_request("do mixed things")
        expect(result["success"]).to be false
        expect(result["command"]).to be_nil
        expect(result["response"]).to eq("Sorry, I can't run that command as parts of it might not be allowed.")
      end
    end

    context 'when AI needs to use the find_maps tool first' do
      let(:initial_request) { "change map to something like process" }
      let(:map_query) { "process" }
      let(:map_search_results) { [ "cp_process_f12", "cp_process_final" ] }

      let(:first_openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "call_map_search",
                    "type" => "function",
                    "function" => {
                      "name" => "find_maps",
                      "arguments" => { query: map_query }.to_json
                    }
                  }
                ]
              }
            }
          ]
        }
      end

      let(:second_openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "call_submit",
                    "type" => "function",
                    "function" => {
                      "name" => "submit_server_action",
                      "arguments" => {
                        command: "changelevel cp_process_f12",
                        response: "Okay, changing map to cp_process_f12.",
                        success: true
                      }.to_json
                    }
                  }
                ]
              }
            }
          ]
        }
      end

      before do
        map_search_service_instance = instance_double(MapSearchService)
        allow(MapSearchService).to receive(:new).with(map_query).and_return(map_search_service_instance)
        allow(map_search_service_instance).to receive(:search).and_return(map_search_results)

        allow(OpenaiClient).to receive(:chat)
          .and_return(first_openai_response, second_openai_response)
      end

      it 'calls find_maps, then executes the command from the second response' do
        expect(MapSearchService).to receive(:new).with(map_query).and_call_original
        expect(server).to receive(:rcon_exec).with("changelevel cp_process_f12")
        expect(server).to receive(:rcon_say).with("Okay, changing map to cp_process_f12.")
        expect(Rails.cache).to receive(:write)

        result = handler.process_request(initial_request)

        expect(result["success"]).to be true
        expect(result["command"]).to eq("changelevel cp_process_f12")
        expect(result["response"]).to eq("Okay, changing map to cp_process_f12.")
      end
    end

    context 'when AI uses find_server_commands tool first' do
      let(:initial_request) { "what's the command for timelimit?" }
      let(:command_query) { "timelimit" }
      let(:command_search_results) { "mp_timelimit <minutes>" }

      let(:first_openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "call_cmd_search",
                    "type" => "function",
                    "function" => {
                      "name" => "find_server_commands",
                      "arguments" => { query: command_query }.to_json
                    }
                  }
                ]
              }
            }
          ]
        }
      end

      let(:second_openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => nil,
                "tool_calls" => [
                  {
                    "id" => "call_submit_info",
                    "type" => "function",
                    "function" => {
                      "name" => "submit_server_action",
                      "arguments" => {
                        command: nil,
                        response: "The command is: mp_timelimit <minutes>",
                        success: true
                      }.to_json
                    }
                  }
                ]
              }
            }
          ]
        }
      end

      before do
        allow(OpenaiClient).to receive(:chat)
          .and_return(first_openai_response, second_openai_response)
      end

      it 'calls find_server_commands, then provides the info via submit_server_action' do
        allow(handler).to receive(:perform_command_search)
          .with({ "query" => command_query })
          .and_return({ results: command_search_results })

        expect(server).not_to receive(:rcon_exec).with(nil)
        expect(server).to receive(:rcon_say).with("The command is: mp_timelimit <minutes>")
        expect(Rails.cache).to receive(:write)

        result = handler.process_request(initial_request)

        expect(result["success"]).to be true
        expect(result["command"]).to be_nil
        expect(result["response"]).to eq("The command is: mp_timelimit <minutes>")
      end
    end

    context 'when AI fails to use submit_server_action tool' do
      let(:openai_response_text) do
        {
          "choices" => [ { "message" => { "content" => "Just some text, not a tool call." } } ]
        }
      end
      let(:openai_response_wrong_tool) do
         {
          "choices" => [ { "message" => { "tool_calls" => [ { "id" => "c1", "type" => "function", "function" => { "name" => "find_maps", "arguments" => { query: "irrelevant_query" }.to_json } } ] } } ]
         }
      end

      it 'returns success: false when AI returns text instead of submit tool' do
         allow(OpenaiClient).to receive(:chat).and_return(openai_response_text)
         expect(Rails.logger).to receive(:error).with(include("Responded with text instead of using 'submit_server_action'"))
         result = handler.process_request("test")
         expect(result["success"]).to be false
         expect(result["response"]).to match(/AI response format error/)
      end

       it 'returns success: false when AI returns a different tool instead of submit tool' do
         allow(OpenaiClient).to receive(:chat).and_return(openai_response_wrong_tool)
         expect(Rails.logger).to receive(:error).with(include("Failed to use 'submit_server_action' tool after intermediate tool call"))
         result = handler.process_request("test")
         expect(result["success"]).to be false
         expect(result["response"]).to match(/Internal error|AI failed to provide a structured final response/)
       end
    end
  end
end
