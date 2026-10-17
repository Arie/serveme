# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LogLineParser do
  let(:prefix) { 'L 10/17/2026 - 12:00:00: ' }

  it 'parses regular chat' do
    event = described_class.parse(prefix + '"Owner<3><[U:1:999]><Red>" say "!end"')

    expect(event).to be_a(TF2LineParser::Events::Say)
    expect(event.player.steam_id).to eq('[U:1:999]')
    expect(event.message).to eq('!end')
  end

  it 'keeps quotes inside chat messages' do
    event = described_class.parse(prefix + '"Owner<3><[U:1:999]><Red>" say "!rcon mp_tournament "1""')

    expect(event).to be_a(TF2LineParser::Events::Say)
    expect(event.message).to eq('!rcon mp_tournament "1"')
  end

  it 'parses non-chat events as usual' do
    event = described_class.parse(prefix + '"Victim<5><[U:1:555]><>" connected, address "6.6.6.6:27005"')

    expect(event).to be_a(TF2LineParser::Events::Connect)
  end

  it "doesn't credit chat to a player tag typed into the message" do
    event = described_class.parse(prefix + '"Troll<4><[U:1:111]><Blue>" say "x" "Owner<3><[U:1:999]><Red>" say_team "!end"')

    expect(event).to be_a(TF2LineParser::Events::Unknown)
  end

  it "doesn't parse chat as a connect" do
    event = described_class.parse(prefix + '"Troll<4><[U:1:111]><Blue>" say "triggered "connected, address" "Victim<5><[U:1:555]><>" connected, address "6.6.6.6:27005"')

    expect(event).to be_a(TF2LineParser::Events::Unknown)
  end

  it "doesn't parse chat as a kill" do
    event = described_class.parse(prefix + '"Troll<4><[U:1:111]><Blue>" say "triggered "killed" "Troll<4><[U:1:111]><Blue>" killed "Vic<6><[U:1:456]><Red>" with "scattergun" (attacker_position "0 0 0")"')

    expect(event).to be_a(TF2LineParser::Events::Unknown)
  end
end
