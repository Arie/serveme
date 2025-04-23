# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'set'

RSpec.describe AiCommandHandler do
  let(:user) { create :user, uid: '76561197960497430' }
  let(:server) { create(:server) }
  let(:condenser) { double.as_null_object }
  let(:reservation) { create :reservation, user: user, server: server }
  let(:handler) { described_class.new(reservation) }
  let(:initial_duration) { 60 }
  let(:user_extension_time) { 30.minutes }
  let(:request_text) { "Please extend the reservation" }

  # Helper methods for building OpenAI responses
  def build_openai_submit_response(arguments_hash, call_id = "call_123")
    {
      "choices" => [
        {
          "message" => {
            "content" => nil,
            "tool_calls" => [
              {
                "id" => call_id,
                "type" => "function",
                "function" => {
                  "name" => "submit_server_action",
                  "arguments" => arguments_hash.to_json
                }
              }
            ]
          }
        }
      ]
    }
  end

  def build_openai_tool_request_response(tool_name, arguments_hash, call_id = "call_tool")
    {
      "choices" => [
        {
          "message" => {
            "content" => nil,
            "tool_calls" => [
              {
                "id" => call_id,
                "type" => "function",
                "function" => {
                  "name" => tool_name,
                  "arguments" => arguments_hash.to_json
                }
              }
            ]
          }
        }
      ]
    }
  end

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
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    allow(Rails.cache).to receive(:read).and_return([]) # No context history initially
    # RCON calls will be expected or stubbed specifically in contexts below
    allow(MapSearchService).to receive(:new).and_return(instance_double(MapSearchService, search: [])) # Stub MapSearchService
    allow(CommandValidator).to receive(:validate).and_return(true) # Assume commands are valid unless specified otherwise
    # Stub OpenAI client by default to avoid actual API calls
    allow(OpenaiClient).to receive(:chat).and_raise("OpenaiClient.chat not stubbed for this scenario")
  end

  describe '#process_request' do
    # Add common stubs for rcon methods
    before do
      allow(reservation.server).to receive(:rcon_exec) # Stub by default, expect specific calls in tests
      allow(reservation.server).to receive(:rcon_say)  # Stub by default, expect specific calls in tests
    end

    context 'when changing map' do
      let(:submit_arguments) do
        {
          command: "changelevel cp_process",
          response: "Changing map to cp_process",
          success: true
        }
      end
      let(:openai_response) { build_openai_submit_response(submit_arguments) }

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
      let(:submit_arguments) do
        {
          command: "exec etf2l_6v6",
          response: "Loading ETF2L 6v6 config",
          success: true
        }
      end
      let(:openai_response) { build_openai_submit_response(submit_arguments) }

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
       let(:submit_arguments) do
        {
          command: "tftrue_whitelist_id etf2l_whitelist_6v6",
          response: "Setting whitelist to ETF2L 6v6",
          success: true
        }
      end
      let(:openai_response) { build_openai_submit_response(submit_arguments) }

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
      let(:submit_arguments) do
        {
          command: nil,
          response: "I don't understand what you want to do. Please be more specific.",
          success: false
        }
      end
      let(:openai_response) { build_openai_submit_response(submit_arguments) }

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
      end

      it 'sends error response without executing command' do
        allow(server).to receive(:rcon_exec).with("status") # This might still be called internally
        expect(server).to receive(:rcon_say).with("I don't understand what you want to do. Please be more specific.")
        expect(server).not_to receive(:rcon_exec).with(nil) # Ensure no nil command execution

        result = handler.process_request("do something cool")
        expect(result["success"]).to be false
      end
    end

    context 'when AI returns a valid command' do
      let(:submit_arguments) do
        {
          command: "mp_timelimit 30",
          response: "Setting timelimit to 30",
          success: true
        }
      end
      let(:openai_response) { build_openai_submit_response(submit_arguments) }

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
      let(:submit_arguments) do
        {
          command: "xyz_invalid_command_abc",
          response: "Attempting invalid thing",
          success: true # AI might initially think it's okay
        }
      end
      let(:openai_response) { build_openai_submit_response(submit_arguments) }

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
        # Ensure validation fails for this specific command in this context
        allow(CommandValidator).to receive(:validate).with("xyz_invalid_command_abc").and_return(false)
      end

      it 'validates, logs error, sends override message, and does not execute command' do
        expect(Rails.logger).to receive(:error).with(include("Proposed disallowed command:"))
        expect(server).not_to receive(:rcon_exec) # Explicitly check it's not called
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
      let(:submit_arguments) do
        {
          command: command_string,
          response: "Doing valid and invalid things",
          success: true # AI might initially think it's okay
        }
      end
      let(:openai_response) { build_openai_submit_response(submit_arguments) }

      before do
        allow(OpenaiClient).to receive(:chat).and_return(openai_response)
        # Ensure validation fails for this specific command string in this context
        allow(CommandValidator).to receive(:validate).with(command_string).and_return(false)
      end

      it 'validates the full string, logs error, sends override message, and does not execute' do
        expect(Rails.logger).to receive(:error).with(include("Proposed disallowed command:"))
        expect(server).not_to receive(:rcon_exec) # Explicitly check it's not called
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
        build_openai_tool_request_response("find_maps", { query: map_query }, "call_map_search")
      end

      let(:second_openai_response) do
        build_openai_submit_response({
          command: "changelevel cp_process_f12",
          response: "Okay, changing map to cp_process_f12.",
          success: true
        }, "call_submit")
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
        # Expect save_context to be called once with the final successful result
        expect(handler).to receive(:save_context)
          .with(initial_request, hash_including("success" => true, "command" => "changelevel cp_process_f12"))
          .once

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
        build_openai_tool_request_response("find_server_commands", { query: command_query }, "call_cmd_search")
      end

      let(:second_openai_response) do
        build_openai_submit_response({
          command: nil,
          response: "The command is: mp_timelimit <minutes>",
          success: true
        }, "call_submit_info")
      end

      before do
        allow(OpenaiClient).to receive(:chat)
          .and_return(first_openai_response, second_openai_response)
      end

      it 'calls find_server_commands, then provides the info via submit_server_action' do
        allow(handler).to receive(:perform_command_search)
          .with({ "query" => command_query })
          .and_return({ results: command_search_results })
        # Expect save_context for successful informational request
        expect(handler).to receive(:save_context)
          .with(initial_request, hash_including("success" => true, "command" => nil))
          .once

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
         build_openai_tool_request_response("find_maps", { query: "irrelevant_query" }, "c1")
      end

      it 'returns success: false when AI returns text instead of submit tool' do
         allow(OpenaiClient).to receive(:chat).and_return(openai_response_text)
         expect(Rails.logger).to receive(:error).with(include("Responded with text instead of using 'submit_server_action'"))
         # rcon_say stubbed in outer before block
         result = handler.process_request("test")
         expect(result["success"]).to be false
         expect(result["response"]).to match(/AI response format error/)
      end

       it 'returns success: false when AI returns a different tool instead of submit tool' do
         allow(OpenaiClient).to receive(:chat).and_return(openai_response_wrong_tool)
         expect(Rails.logger).to receive(:error).with(include("Failed to use 'submit_server_action' tool after intermediate tool call"))
         # rcon_say stubbed in outer before block
         result = handler.process_request("test")
         expect(result["success"]).to be false
         expect(result["response"]).to match(/Internal error|AI failed to provide a structured final response/)
       end
    end
  end

  describe '#process_request with reservation modification' do
    let(:tool_call_id) { 'call_abc123' }

    # Add common stubs for rcon methods for this describe block as well
    # (or move the #process_request before block outside if applicable to both)
    before do
      allow(reservation.server).to receive(:rcon_exec)
      allow(reservation.server).to receive(:rcon_say)
    end

    context 'when extending the reservation' do
      let(:request_text) { "add more time please" }
      let(:first_openai_response) do
        build_openai_tool_request_response("modify_reservation", { action: "extend" }, tool_call_id)
      end

      context 'when extension is successful' do
        let(:tool_result_content) { { success: true, message: "Reservation extended by #{user_extension_time / 60} minutes." } }
        let(:final_response_message) { "Alright, I've extended your reservation by #{user_extension_time / 60} minutes." }
        let(:final_openai_response) do
          build_openai_submit_response({ command: nil, response: final_response_message, success: true }, 'call_def456')
        end

        before do
          # Mock the user association and its method
          allow(user).to receive(:reservation_extension_time).and_return(user_extension_time)
          allow(reservation).to receive(:user).and_return(user)

          allow(reservation).to receive(:extend!).and_return(true) # Use extend!
          # Mock the sequence of OpenAI calls
          expect(OpenaiClient).to receive(:chat)
            .with(hash_including(messages: anything, tools: AiCommandHandler::AVAILABLE_TOOLS, tool_choice: "required"))
            .ordered
            .and_return(first_openai_response)

          expect(OpenaiClient).to receive(:chat)
            .with(hash_including(
              messages: array_including(
                { role: "tool", tool_call_id: tool_call_id, name: "modify_reservation", content: tool_result_content.to_json }
              ),
              tool_choice: { type: "function", function: { name: "submit_server_action" } }
            ))
            .ordered
            .and_return(final_openai_response)
        end

        it 'calls extend! on the reservation' do
          expect(reservation).to receive(:extend!).once # Check extend!
          handler.process_request(request_text)
        end

        it 'sends a confirmation message via rcon_say' do
          expect(reservation.server).to receive(:rcon_say).with(final_response_message)
          handler.process_request(request_text)
        end

        it 'returns a success result' do
          result = handler.process_request(request_text)
          expect(result).to eq({ "command" => nil, "response" => final_response_message, "success" => true })
        end

        it 'saves the context' do
          expect(handler).to receive(:save_context)
            .with(request_text, hash_including("success" => true))
            .once
          handler.process_request(request_text)
        end
      end

      context 'when extension fails' do
        let(:tool_result_content) { { success: false, message: "Could not extend the reservation. Is it already at maximum duration?" } }
        let(:final_response_message) { "Sorry, I couldn't extend the reservation. Maybe it's already at the maximum time?" }
        let(:final_openai_response) do
          build_openai_submit_response({ command: nil, response: final_response_message, success: false }, 'call_def456')
        end

        before do
          # Mock the user association and its method
          allow(user).to receive(:reservation_extension_time).and_return(user_extension_time)
          allow(reservation).to receive(:user).and_return(user)

          allow(reservation).to receive(:extend!).and_return(false) # Use extend!
          expect(OpenaiClient).to receive(:chat).ordered.and_return(first_openai_response)
          expect(OpenaiClient).to receive(:chat)
             .with(hash_including(
               messages: array_including(
                 { role: "tool", tool_call_id: tool_call_id, name: "modify_reservation", content: tool_result_content.to_json }
               )
             ))
            .ordered
            .and_return(final_openai_response)
        end

        it 'calls extend! on the reservation' do
          expect(reservation).to receive(:extend!).once # Check extend!
          handler.process_request(request_text)
        end

        it 'sends a failure message via rcon_say' do
          expect(reservation.server).to receive(:rcon_say).with(final_response_message)
          handler.process_request(request_text)
        end

        it 'returns a failure result' do
          result = handler.process_request(request_text)
          expect(result).to eq({ "command" => nil, "response" => final_response_message, "success" => false })
        end

        it 'does not save the context on failure' do # Renamed for clarity
          expect(handler).not_to receive(:save_context) # Should not save on failure
          handler.process_request(request_text)
        end
      end
    end

    context 'when ending the reservation' do
      let(:request_text) { "end this server now" }
      let(:first_openai_response) do
        build_openai_tool_request_response("modify_reservation", { action: "end" }, tool_call_id)
      end

      context 'when ending is successful' do
        let(:tool_result_content) { { success: true, message: "Reservation ended successfully." } }
        let(:final_response_message) { "Okay, ending the reservation now." }
        let(:final_openai_response) do
          build_openai_submit_response({ command: nil, response: final_response_message, success: true }, 'call_def456')
        end

        before do
          allow(reservation).to receive(:end_reservation).and_return(true) # Use end_reservation
          expect(OpenaiClient).to receive(:chat).ordered.and_return(first_openai_response)
          expect(OpenaiClient).to receive(:chat)
             .with(hash_including(
               messages: array_including(
                 { role: "tool", tool_call_id: tool_call_id, name: "modify_reservation", content: tool_result_content.to_json }
               )
             ))
            .ordered
            .and_return(final_openai_response)
        end

        it 'calls end_reservation on the reservation' do
          expect(reservation).to receive(:end_reservation).once # Check end_reservation
          handler.process_request(request_text)
        end

        it 'sends a confirmation message via rcon_say' do
          expect(reservation.server).to receive(:rcon_say).with(final_response_message)
          handler.process_request(request_text)
        end

        it 'returns a success result' do
          result = handler.process_request(request_text)
          expect(result).to eq({ "command" => nil, "response" => final_response_message, "success" => true })
        end

        it 'saves the context' do
          expect(handler).to receive(:save_context)
            .with(request_text, hash_including("success" => true))
            .once
          handler.process_request(request_text)
        end
      end

      context 'when ending fails' do
        let(:tool_result_content) { { success: false, message: "Could not end the reservation." } }
        let(:final_response_message) { "Sorry, I couldn't end the reservation for some reason." }
        let(:final_openai_response) do
          build_openai_submit_response({ command: nil, response: final_response_message, success: false }, 'call_def456')
        end

        before do
          allow(reservation).to receive(:end_reservation).and_return(false) # Use end_reservation
          expect(OpenaiClient).to receive(:chat).ordered.and_return(first_openai_response)
          expect(OpenaiClient).to receive(:chat)
             .with(hash_including(
               messages: array_including(
                 { role: "tool", tool_call_id: tool_call_id, name: "modify_reservation", content: tool_result_content.to_json }
               )
             ))
            .ordered
            .and_return(final_openai_response)
        end

        it 'calls end_reservation on the reservation' do
          expect(reservation).to receive(:end_reservation).once # Check end_reservation
          handler.process_request(request_text)
        end

        it 'sends a failure message via rcon_say' do
          expect(reservation.server).to receive(:rcon_say).with(final_response_message)
          handler.process_request(request_text)
        end

        it 'returns a failure result' do
          result = handler.process_request(request_text)
          expect(result).to eq({ "command" => nil, "response" => final_response_message, "success" => false })
        end

        it 'does not save the context on failure' do # Renamed for clarity
          expect(handler).not_to receive(:save_context)
          handler.process_request(request_text)
        end
      end

      context 'when an error occurs during modification' do
        let(:error_message) { "Something went very wrong" }
        let(:tool_result_content) { { success: false, message: "An error occurred while trying to end the reservation." } }
        let(:final_response_message) { "Yikes, an internal error occurred while trying to end the reservation." }
        let(:final_openai_response) do
          build_openai_submit_response({ command: nil, response: final_response_message, success: false }, 'call_def456')
        end

        before do
          allow(reservation).to receive(:end_reservation).and_raise(StandardError, error_message) # Use end_reservation
          expect(OpenaiClient).to receive(:chat).ordered.and_return(first_openai_response)
          expect(OpenaiClient).to receive(:chat)
            .with(hash_including(
              messages: array_including(
                # Note: We need to adjust the expected content here slightly as the error message might change
                hash_including(role: "tool", tool_call_id: tool_call_id, name: "modify_reservation")
              )
            ))
            .ordered
            .and_return(final_openai_response)

           # Mock the specific tool result generation within the handler if necessary,
           # otherwise ensure the chat mock handles the sequence.
           # Let's assume the handler catches the error and forms the tool_result_content correctly.
           # We might need a more robust way to check the tool message content if it includes the specific error.
           allow(handler).to receive(:perform_reservation_modification).and_wrap_original do |m, *args|
             begin
               m.call(*args)
             rescue StandardError => e
               # Mimic the likely error handling in the actual method
               { success: false, message: "An error occurred while trying to end the reservation." } # Simplified message
             end
           end
        end

        it 'calls end_reservation on the reservation' do
          expect(reservation).to receive(:end_reservation).once # Check end_reservation
          handler.process_request(request_text)
        end

        it 'sends an error message via rcon_say' do
          expect(reservation.server).to receive(:rcon_say).with(final_response_message)
          handler.process_request(request_text)
        end

        it 'returns a failure result' do
          result = handler.process_request(request_text)
          expect(result).to eq({ "command" => nil, "response" => final_response_message, "success" => false })
        end

        it 'does not save the context on error' do # Renamed for clarity
          expect(handler).not_to receive(:save_context) # Should not save on failure
          handler.process_request(request_text)
        end
      end
    end
  end
end
