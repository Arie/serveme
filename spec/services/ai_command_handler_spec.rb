# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'set'

RSpec.describe AiCommandHandler do
  let(:user) { build_stubbed :user, uid: '76561197960497430' }
  let(:server) { build_stubbed(:server) }
  let(:condenser) { double.as_null_object }
  let(:reservation) { build_stubbed :reservation, user: user, server: server }
  let(:handler) { described_class.new(reservation) }
  let(:initial_duration) { 60 }
  let(:user_extension_time) { 30.minutes }
  let(:request_text) { "Please extend the reservation" }

  # Helper methods for building OpenAI responses
  define_method(:build_openai_submit_response) do |arguments_hash, call_id = "call_123"|
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

  define_method(:build_openai_tool_request_response) do |tool_name, arguments_hash, call_id = "call_tool"|
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
      allow(LeagueMaps).to receive(:grouped_league_maps).and_return([])
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
        # Context is now persisted even on failure so follow-up confirmations have history
        expect(Rails.cache).to receive(:write).with(/ai_context_history/, anything, expires_in: 1.hour)

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
        # Context is now persisted even on failure so follow-up confirmations have history
        expect(Rails.cache).to receive(:write).with(/ai_context_history/, anything, expires_in: 1.hour)

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

    context 'when the OpenAI request raises an error' do
      before do
        allow(OpenaiClient).to receive(:chat).and_raise(StandardError, "the server responded with status 400")
      end

      it 'reports the error to the player in-game and returns a failure result' do
        expect(server).to receive(:rcon_say).with("An unexpected error occurred. Please try again.")

        result = handler.process_request("how is my ping looking?")

        expect(result["success"]).to be false
        expect(result["response"]).to eq("An unexpected error occurred. Please try again.")
        expect(result["command"]).to be_nil
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
      allow(LeagueMaps).to receive(:grouped_league_maps).and_return([])
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
              tool_choice: "required"
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

        it 'still saves the context on failure so follow-up confirmations have history' do
          expect(handler).to receive(:save_context)
            .with(request_text, hash_including("success" => false))
            .once
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

        it 'still saves the context on failure so follow-up confirmations have history' do
          expect(handler).to receive(:save_context)
            .with(request_text, hash_including("success" => false))
            .once
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

        it 'still saves the context on error so follow-up confirmations have history' do
          expect(handler).to receive(:save_context)
            .with(request_text, hash_including("success" => false))
            .once
          handler.process_request(request_text)
        end
      end
    end
  end

  describe 'conversation history replay' do
    before do
      allow(reservation.server).to receive(:rcon_exec)
      allow(reservation.server).to receive(:rcon_say)
      allow(LeagueMaps).to receive(:grouped_league_maps).and_return([])
    end

    it 'replays prior turns (including failed clarifications) as submit_server_action tool call/result pairs' do
      history = [
        { "request" => "change to gully", "response" => "Right then.", "command" => "changelevel cp_gullywash_f9", "success" => true },
        { "request" => "rename blue team?", "response" => "Which name do you want?", "command" => nil, "success" => false }
      ]
      allow(handler).to receive(:get_previous_context).and_return(history)

      captured_messages = nil
      allow(OpenaiClient).to receive(:chat) do |args|
        captured_messages = args[:messages]
        build_openai_submit_response({ command: nil, response: "ok", success: true })
      end

      handler.process_request("yes")

      assistant_tool_calls = captured_messages
        .select { |m| m[:role] == "assistant" }
        .flat_map { |m| m[:tool_calls] || [] }
      tool_messages = captured_messages.select { |m| m[:role] == "tool" }

      expect(assistant_tool_calls.size).to eq(2)
      expect(assistant_tool_calls.map { |tc| tc[:function][:name] }).to all(eq("submit_server_action"))
      # every assistant tool_call is answered by a matching tool result (valid OpenAI message order)
      expect(tool_messages.map { |m| m[:tool_call_id] }).to match_array(assistant_tool_calls.map { |tc| tc[:id] })

      # the failed clarification is preserved so a bare "yes" has context to confirm against
      replayed = assistant_tool_calls.map { |tc| JSON.parse(tc[:function][:arguments]) }
      expect(replayed).to include(hash_including("success" => false, "response" => "Which name do you want?", "command" => nil))
    end
  end

  describe '#save_context' do
    let(:store) { ActiveSupport::Cache::MemoryStore.new }

    before { allow(Rails).to receive(:cache).and_return(store) }

    it 'persists a failed clarification turn so follow-ups can resolve it' do
      handler.send(:save_context, "rename blue team?", { "response" => "Which name?", "command" => nil, "success" => false })

      saved = store.read("ai_context_history:#{reservation.id}")
      expect(saved.last).to include("request" => "rename blue team?", "command" => nil, "success" => false)
    end
  end

  describe 'multi-step tool use' do
    before do
      allow(server).to receive(:rcon_exec).and_return("")
      allow(server).to receive(:rcon_say)
      allow(MapSearchService).to receive(:new).and_return(instance_double(MapSearchService, search: [ "cp_process_f12" ]))
    end

    it 'allows a map lookup and a command lookup before submitting' do
      allow(OpenaiClient).to receive(:chat).and_return(
        build_openai_tool_request_response("find_maps", { query: "process" }, "c1"),
        build_openai_tool_request_response("find_server_commands", { query: "mp_winlimit" }, "c2"),
        build_openai_submit_response({ command: "changelevel cp_process_f12", response: "Changing map.", success: true }, "c3")
      )

      result = handler.process_request("put process on with the right winlimit")

      expect(OpenaiClient).to have_received(:chat).exactly(3).times
      expect(result["command"]).to eq("changelevel cp_process_f12")
    end

    it 'answers every tool_call_id when the model asks for several tools at once' do
      parallel = build_openai_tool_request_response("find_maps", { query: "gully" }, "call_a")
      parallel["choices"][0]["message"]["tool_calls"] << {
        "id" => "call_b",
        "type" => "function",
        "function" => { "name" => "find_server_commands", "arguments" => { query: "mp_winlimit" }.to_json }
      }
      responses = [ parallel, build_openai_submit_response({ command: "changelevel cp_gullywash_f9", response: "Done.", success: true }, "c2") ]
      calls = []
      allow(OpenaiClient).to receive(:chat) { |params| calls << params; responses.shift }

      handler.process_request("change the map to gully and set winlimit 5")

      # OpenAI rejects the follow-up with a 400 unless both ids get a tool message back.
      answered = calls.last[:messages].select { |m| m[:role] == "tool" }.map { |m| m[:tool_call_id] }
      expect(answered).to contain_exactly("call_a", "call_b")
    end

    it 'forces submit_server_action once MAX_TOOL_ROUNDS lookups have happened' do
      looping = build_openai_tool_request_response("find_maps", { query: "process" }, "c1")
      allow(OpenaiClient).to receive(:chat).and_return(
        looping, looping, looping,
        build_openai_submit_response({ command: nil, response: "I need more to go on.", success: false }, "c4")
      )

      handler.process_request("something that keeps searching")

      expect(OpenaiClient).to have_received(:chat)
        .with(hash_including(tool_choice: { type: "function", function: { name: "submit_server_action" } })).once
      expect(OpenaiClient).to have_received(:chat).exactly(described_class::MAX_TOOL_ROUNDS + 1).times
    end
  end

  describe 'system prompt safety rails' do
    before { allow(LeagueMaps).to receive(:grouped_league_maps).and_return([]) }

    let(:prompt) { handler.send(:system_prompt, reservation) }

    it 'documents the destructive-guessing, no-substitution, scope and confirmation rules' do
      expect(prompt).to include("NO DESTRUCTIVE GUESSING")
      expect(prompt).to include("NO SUBSTITUTING A DIFFERENT ACTION")
      expect(prompt).to include("kick means kick and slay means slay")
      expect(prompt).to include("sm_setteam")
      expect(prompt).to include("Changing a player's class is done with sm_setclass")
      expect(prompt).to include("CONFIRMATIONS")
      expect(prompt).to include("EXACT COMMANDS")
    end

    it 'documents the whitelist-id and per-player rename rules' do
      expect(prompt).to include("tftrue_whitelist_id 18740")
      expect(prompt).to include("one sm_rename per userid")
    end

    it 'blocks sm_setteam when the setteam plugin is not loaded on this server' do
      handler.instance_variable_set(:@server_status, "[SM] Listing 15 plugins: basecommands, basechat")
      allow(reservation.server).to receive(:rcon_say)
      expect(reservation.server).not_to receive(:rcon_exec)

      handler.send(:process_ai_result,
                   { "command" => "sm_setteam #15 blue", "response" => "Moving them.", "success" => true },
                   "move maya to blue")

      expect(reservation.server).to have_received(:rcon_say).with(/setteam plugin/)
    end

    it 'allows sm_setteam when the setteam plugin is loaded' do
      handler.instance_variable_set(:@server_status, "[SM] Listing 48 plugins: basecommands, setteam, stac")
      allow(reservation.server).to receive(:rcon_say)
      allow(reservation.server).to receive(:rcon_exec)

      handler.send(:process_ai_result,
                   { "command" => "sm_setteam #15 blue", "response" => "Moving them.", "success" => true },
                   "move maya to blue")

      expect(reservation.server).to have_received(:rcon_exec).with("sm_setteam #15 blue")
    end

    it 'blocks sm_setclass when the setclass plugin is not loaded on this server' do
      handler.instance_variable_set(:@server_status, '15 "Basic Commands" (1.12.0.7253)')
      allow(reservation.server).to receive(:rcon_say)
      expect(reservation.server).not_to receive(:rcon_exec)

      handler.send(:process_ai_result,
                   { "command" => "sm_setclass #14 medic", "response" => "On it.", "success" => true },
                   "make emierr medic")

      expect(reservation.server).to have_received(:rcon_say).with(/setclass plugin/)
    end

    it 'allows sm_setclass when the setclass plugin is loaded' do
      handler.instance_variable_set(:@server_status, '49 "TF2 Set Class" (1.3.0) by Tylerst, avi9526, JoinedSenses')
      allow(reservation.server).to receive(:rcon_say)
      allow(reservation.server).to receive(:rcon_exec)

      handler.send(:process_ai_result,
                   { "command" => "sm_setclass #14 medic", "response" => "On it.", "success" => true },
                   "make emierr medic")

      expect(reservation.server).to have_received(:rcon_exec).with("sm_setclass #14 medic")
    end

    it 'only documents rcon commands that CommandValidator will actually allow' do
      # Bullets above the local-player-commands section are commands the AI may run,
      # so each one has to be allowlisted or the whole command string gets rejected.
      # These bullets are tool parameters, target syntax and team compositions, not commands.
      non_commands = %w[command response success player groups teams ultiduo ultitrio highlander pass serveme na sea au]
      rcon_section = prompt.split("Local player commands").first

      documented = rcon_section.scan(/^\s*- ([a-z_][a-z0-9_]*)/).flatten.uniq - non_commands
      undocumented = documented.reject do |cmd|
        # A trailing underscore is a placeholder, e.g. tf_tournament_classlimit_<class>
        cmd.end_with?("_") ? ALLOWED_SERVER_COMMANDS.any? { |a| a.start_with?(cmd) } : ALLOWED_SERVER_COMMANDS.include?(cmd)
      end

      expect(undocumented).to be_empty, "prompt documents commands missing from ALLOWED_SERVER_COMMANDS: #{undocumented.join(', ')}"
    end

    it 'documents every player-movement and kick command that CommandValidator allows' do
      %w[kickid sm_kick sm_setteam sm_forceteam].each do |command|
        expect(ALLOWED_SERVER_COMMANDS).to include(command)
        expect(prompt).to include(command)
      end
    end
  end

  describe 'malformed OpenAI responses' do
    before do
      allow(server).to receive(:rcon_say)
      allow(LeagueMaps).to receive(:grouped_league_maps).and_return([])
    end

    define_method(:tool_call_response) do |name, raw_arguments|
      { "choices" => [ { "message" => { "content" => nil, "tool_calls" => [
        { "id" => "c1", "type" => "function", "function" => { "name" => name, "arguments" => raw_arguments } }
      ] } } ] }
    end

    it 'reports unparseable tool arguments' do
      allow(OpenaiClient).to receive(:chat).and_return(tool_call_response("find_maps", "{not json"))
      expect(Rails.logger).to receive(:error).with(include("Failed to parse arguments for tool 'find_maps'"))

      result = handler.process_request("change map")

      expect(result).to eq("success" => false, "response" => "Internal error processing AI tool arguments.", "command" => nil)
    end

    it 'names the final submit call when arguments break after a lookup' do
      allow(OpenaiClient).to receive(:chat).and_return(
        build_openai_tool_request_response("find_maps", { query: "badwater" }),
        tool_call_response("submit_server_action", "{not json")
      )
      expect(Rails.logger).to receive(:error).with(include("Failed to parse arguments for final submit_server_action call"))

      expect(handler.process_request("change map")["success"]).to be false
    end

    it 'rejects tools it does not know' do
      allow(OpenaiClient).to receive(:chat).and_return(build_openai_tool_request_response("rm_rf", {}))
      expect(Rails.logger).to receive(:error).with(include("Requested unknown tool: rm_rf"))

      expect(handler.process_request("do it")["response"]).to eq("Internal error: AI requested an unknown tool.")
    end

    it 'handles a response with neither content nor tool calls' do
      allow(OpenaiClient).to receive(:chat).and_return({ "choices" => [ { "message" => { "content" => nil } } ] })
      expect(Rails.logger).to receive(:error).with(include("Response had neither content nor tool calls"))

      expect(handler.process_request("hi")["response"]).to eq("AI returned an empty or invalid response.")
    end

    it 'tells the player when the response structure is unusable' do
      allow(OpenaiClient).to receive(:chat).and_return({ "choices" => [] })
      allow(Rails.logger).to receive(:error)
      expect(server).to receive(:rcon_say).with("Sorry, I had trouble understanding the AI's response format. Please try again.")

      expect(handler.process_request("hi")["success"]).to be false
    end
  end

  describe 'reservation modification actions' do
    define_method(:modify) { |action| handler.send(:perform_reservation_modification, { "action" => action }) }

    it 'locks the server' do
      expect(reservation).to receive(:lock!)
      expect(reservation).to receive(:status_update).with(include("Server locked via AI command"))

      expect(modify("lock")).to eq(success: true, message: "Server locked. Password changed and no new connections allowed.")
    end

    it 'unlocks a locked server and tells the players' do
      allow(reservation).to receive(:unlock!).and_return(true)
      expect(server).to receive(:rcon_say).with("Server unlocked, original password restored!")
      expect(reservation).to receive(:status_update).with("Server unlocked via AI command")

      expect(modify("unlock")[:success]).to be true
    end

    it 'reports when the server was not locked' do
      allow(reservation).to receive(:unlock!).and_return(false)

      expect(modify("unlock")).to eq(success: false, message: "Server is not currently locked.")
    end

    it 'unbans everyone and records it when bans were lifted' do
      allow(reservation).to receive(:unban_all!).and_return({ count: 2, message: "Unbanned 2 players" })
      expect(reservation).to receive(:status_update).with("Unbanned 2 players via AI command")

      expect(modify("unbanall")).to eq(success: true, message: "Unbanned 2 players")
    end

    it 'does not record an unban when nobody was banned' do
      allow(reservation).to receive(:unban_all!).and_return({ count: 0, message: "No bans" })
      expect(reservation).not_to receive(:status_update)

      expect(modify("unbanall")[:success]).to be true
    end

    it 'reports an unban failure' do
      allow(reservation).to receive(:unban_all!).and_return({ count: nil, message: "Could not read ban list" })

      expect(modify("unbanall")).to eq(success: false, message: "Could not read ban list")
    end

    it 'rejects unknown actions' do
      expect(Rails.logger).to receive(:error).with(include("Unknown action requested in modify_reservation: explode"))

      expect(modify("explode")[:success]).to be false
    end
  end

  describe 'tool dispatch' do
    it 'returns an error for tools it cannot perform' do
      expect(Rails.logger).to receive(:error).with(include("Unknown action requested in perform_tool_action: nope"))

      expect(handler.send(:perform_tool_action, "nope", {})).to eq(error: "Unknown tool action")
    end

    it 'strips shell-ish characters from command searches' do
      expect(server).to receive(:rcon_exec).with('find "mp_time quit"').and_return("mp_timelimit")

      expect(handler.send(:perform_command_search, { "query" => 'mp_time; "quit"' })).to eq(results: "mp_timelimit")
    end
  end

  describe '#fetch_server_status' do
    it 'queries the server and masks IP addresses' do
      allow(server).to receive(:rcon_exec).with(start_with("status;")).and_return("udp/ip  : 1.2.3.4:27015 (public IP from Steam: 5.6.7.8)")

      expect(handler.send(:fetch_server_status)).to eq("udp/ip  : 0.0.0.0:27015 (public IP from Steam: 0.0.0.0)")
    end
  end

  describe 'sayer identity' do
    define_method(:sayer_message) do |sayer|
      handler.instance_variable_set(:@sayer, sayer)
      handler.send(:sayer_info_message)
    end

    it 'is omitted without a sayer or steam id' do
      expect(sayer_message(nil)).to be_nil
      expect(sayer_message({ name: "anon", steam_uid: nil })).to be_nil
    end

    it 'describes a registered admin donator who made the reservation' do
      allow(User).to receive(:find_by).with(uid: user.uid).and_return(user)
      allow(user).to receive_messages(admin?: true, donator?: true, nickname: "Arie")

      expect(sayer_message({ name: "Arie - serveme.tf", steam_uid: user.uid.to_i })).to eq(<<~MSG.chomp)
        The player who sent the chat message has the following identity:
        - In-game name: Arie - serveme.tf
        - Steam ID (steamID64): #{user.uid}
        - Account: registered on serveme.tf, admin, donator
        - Site nickname: Arie
        - Is the reservation creator: yes
      MSG
    end

    it 'describes an unregistered player who is not the reserver' do
      allow(User).to receive(:find_by).and_return(nil)

      message = sayer_message({ name: "", steam_uid: "76561197960265729" })

      expect(message).not_to include("In-game name")
      expect(message).to include("- Account: not registered on serveme.tf", "- Is the reservation creator: no")
    end
  end
end
