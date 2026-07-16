# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe ServerRconGateway do
  let(:condenser) { double("condenser") }
  let(:server) { build_stubbed(:server, ip: "fakkelbrigade.eu", port: 27_015) }

  subject(:gateway) { described_class.new(server, condenser: condenser) }

  before { allow(server).to receive(:current_rcon).and_return("rconpass") }

  describe "#condenser" do
    it "builds a source server condenser from the server ip and port when none is injected" do
      gateway = described_class.new(server)
      expect(SteamCondenser::Servers::SourceServer).to receive(:new).with("fakkelbrigade.eu", 27_015)
      gateway.condenser
    end
  end

  describe "#auth" do
    it "authenticates the condenser with the server's current rcon and memoizes it" do
      expect(condenser).to receive(:rcon_auth).with("rconpass").once.and_return(true)
      expect(gateway.auth).to be(true)
      expect(gateway.auth).to be(true)
    end

    it "returns nil on an empty rcon reply (NoMethodError)" do
      allow(condenser).to receive(:rcon_auth).and_raise(NoMethodError)
      expect(gateway.auth).to be_nil
    end
  end

  describe "#exec" do
    before { allow(condenser).to receive(:rcon_auth).and_return(true) }

    it "sends the command to the condenser after authenticating" do
      expect(condenser).to receive(:rcon_exec).with("status").and_return("result")
      expect(gateway.exec("status")).to eq("result")
    end

    it "does not send a blocked command by default" do
      expect(condenser).not_to receive(:rcon_exec)
      expect(gateway.exec("logaddress_add 1.2.3.4")).to be_nil
    end

    it "sends a blocked command when explicitly allowed" do
      expect(condenser).to receive(:rcon_exec).with("sv_downloadurl foo")
      gateway.exec("sv_downloadurl foo", allow_blocked: true)
    end

    it "neutralizes // comment markers outside quotes" do
      expect(condenser).to receive(:rcon_exec).with("say hello/\u200B/world")
      gateway.exec("say hello//world")
    end

    it "preserves // inside quoted strings (e.g. urls)" do
      expect(condenser).to receive(:rcon_exec).with('sm_web_rcon_url "https://serveme.tf"')
      gateway.exec('sm_web_rcon_url "https://serveme.tf"')
    end

    it "escapes every // in unquoted urls (e.g. links in a say)" do
      command = "say Visit https://steamcommunity.com/ and https://etf2l.org/ for more info"
      escaped = "say Visit https:/\u200B/steamcommunity.com/ and https:/\u200B/etf2l.org/ for more info"
      expect(condenser).to receive(:rcon_exec).with(escaped)
      gateway.exec(command)
    end

    it "returns nil and logs when the condenser times out" do
      allow(condenser).to receive(:rcon_exec).and_raise(SteamCondenser::Error::Timeout)
      expect(Rails.logger).to receive(:error)
      expect(gateway.exec("status")).to be_nil
    end
  end

  describe "#say" do
    before { allow(condenser).to receive(:rcon_auth).and_return(true) }

    it "delivers the message as an rcon say" do
      expect(condenser).to receive(:rcon_exec).with("say Hello world!")
      gateway.say("Hello world!")
    end

    it "splits long lines into chunks of at most 200 characters" do
      long = "#{'a' * 150} #{'b' * 150}"
      received = []
      allow(condenser).to receive(:rcon_exec) { |cmd| received << cmd }
      gateway.say(long)
      expect(received.size).to eq(2)
      expect(received).to all(satisfy { |cmd| cmd.length <= 200 + "say ".length })
    end

    it "sends each newline-separated line separately" do
      expect(condenser).to receive(:rcon_exec).with("say one").ordered
      expect(condenser).to receive(:rcon_exec).with("say two").ordered
      gateway.say("one\ntwo")
    end

    it "splits a long single line at word boundaries" do
      long_message = "Welcome to our TF2 server! We're playing some competitive 6v6 matches today. Please make sure to follow the server rules: no cheating, be respectful to other players, communicate with your team, and most importantly have fun! If you need any help just ask an admin. Good luck and have fun everyone! Remember to join our Discord server for announcements and to find other players to queue with."
      expect(condenser).to receive(:rcon_exec).with("say Welcome to our TF2 server! We're playing some competitive 6v6 matches today. Please make sure to follow the server rules: no cheating, be respectful to other players, communicate with your team, and").ordered
      expect(condenser).to receive(:rcon_exec).with("say most importantly have fun! If you need any help just ask an admin. Good luck and have fun everyone! Remember to join our Discord server for announcements and to find other players to queue with.").ordered
      gateway.say(long_message)
    end

    it "logs an error when a chunk fails to send" do
      allow(condenser).to receive(:rcon_exec).and_raise(SteamCondenser::Error::Timeout)
      expect(Rails.logger).to receive(:error)
      gateway.say("foobar")
    end
  end

  describe "#disconnect" do
    it "disconnects the condenser and clears it so a fresh one is built next time" do
      expect(condenser).to receive(:disconnect)
      gateway.disconnect
      expect(SteamCondenser::Servers::SourceServer).to receive(:new).and_return(double(disconnect: nil))
      gateway.condenser
    end

    it "logs and swallows errors from disconnect" do
      allow(condenser).to receive(:disconnect).and_raise(StandardError)
      expect(Rails.logger).to receive(:error)
      expect { gateway.disconnect }.not_to raise_error
    end
  end

  describe "#blocked_command?" do
    it "flags logaddress, rcon_password and sv_downloadurl" do
      expect(gateway.blocked_command?("logaddress_add x")).to be(true)
      expect(gateway.blocked_command?("rcon_password secret")).to be(true)
      expect(gateway.blocked_command?("SV_DOWNLOADURL foo")).to be(true)
      expect(gateway.blocked_command?("status")).to be(false)
    end
  end
end
