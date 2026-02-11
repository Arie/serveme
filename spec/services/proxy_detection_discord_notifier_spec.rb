# typed: false
# frozen_string_literal: true

require "spec_helper"

RSpec.describe ProxyDetectionDiscordNotifier do
  let(:notifier) { described_class.new }

  let(:player_data) do
    {
      "76561198012345678" => {
        name: "ProxyPlayer",
        ips: {
          "1.2.3.4" => { fraud_score: 90, isp: "ShadyVPN", country_code: "US", reservation_ids: [ 100, 101 ] },
          "5.6.7.8" => { fraud_score: 85, isp: "AnotherVPN", country_code: "DE", reservation_ids: [ 102 ] }
        }
      },
      "76561198087654321" => {
        name: "AnotherPlayer",
        ips: {
          "9.10.11.12" => { fraud_score: 75, isp: "SketchyISP", country_code: "NL", reservation_ids: [ 103 ] }
        }
      }
    }
  end

  describe "#notify" do
    it "sends a properly formatted Discord notification" do
      http_double = instance_double(Net::HTTP)
      expect(Net::HTTP).to receive(:new).with(anything, anything).and_return(http_double)
      expect(http_double).to receive(:use_ssl=).with(true)

      expect(http_double).to receive(:request) do |request|
        payload = JSON.parse(request.body)
        embed = payload["embeds"].first

        expect(embed["title"]).to eq("Daily Proxy Detection Report for #{SITE_HOST}")
        expect(embed["color"]).to eq(0xFFA500)
        expect(embed["description"]).to include("2 player(s) detected")

        fields = embed["fields"]
        expect(fields.length).to eq(2)

        proxy_player = fields.find { |f| f["name"] == "ProxyPlayer" }
        expect(proxy_player["value"]).to include("76561198012345678")
        expect(proxy_player["value"]).to include("1.2.3.4")
        expect(proxy_player["value"]).to include("score: 90")
        expect(proxy_player["value"]).to include("ShadyVPN")
        expect(proxy_player["value"]).to include("#100")
        expect(proxy_player["value"]).to include("#101")

        another_player = fields.find { |f| f["name"] == "AnotherPlayer" }
        expect(another_player["value"]).to include("9.10.11.12")
      end

      notifier.notify(player_data)
    end

    it "returns early when player_data is empty" do
      expect(Net::HTTP).not_to receive(:new)
      notifier.notify({})
    end

    it "truncates fields when more than 25 players" do
      many_players = 30.times.each_with_object({}) do |i, hash|
        hash["7656119801234#{format('%04d', i)}"] = {
          name: "Player#{i}",
          ips: { "1.2.3.#{i}" => { fraud_score: 80, isp: "ISP", country_code: "US", reservation_ids: [ i ] } }
        }
      end

      http_double = instance_double(Net::HTTP)
      expect(Net::HTTP).to receive(:new).with(anything, anything).and_return(http_double)
      expect(http_double).to receive(:use_ssl=).with(true)

      expect(http_double).to receive(:request) do |request|
        payload = JSON.parse(request.body)
        fields = payload["embeds"].first["fields"]

        expect(fields.length).to eq(26)
        expect(fields.last["name"]).to eq("...")
        expect(fields.last["value"]).to include("5 more player(s) not shown")
      end

      notifier.notify(many_players)
    end
  end
end
