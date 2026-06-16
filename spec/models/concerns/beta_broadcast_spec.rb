# typed: false
# frozen_string_literal: true

require "spec_helper"

describe BetaBroadcast do
  describe ".stream" do
    it "appends the :v2 variant to a string stream" do
      expect(described_class.stream("server-list")).to eq([ "server-list", :v2 ])
    end

    it "appends the :v2 variant to a model stream" do
      reservation = create(:reservation)
      expect(described_class.stream(reservation)).to eq([ reservation, :v2 ])
    end
  end

  describe ".with_variant" do
    it "adds the v2 variant when rendering a partial" do
      expect(described_class.with_variant(partial: "x", locals: {})).to eq(partial: "x", locals: {}, variants: [ :v2 ])
    end

    it "leaves a pre-rendered html payload untouched" do
      expect(described_class.with_variant(html: "<p>x</p>")).to eq(html: "<p>x</p>")
    end

    it "leaves a content payload untouched" do
      expect(described_class.with_variant(content: "<p>x</p>")).to eq(content: "<p>x</p>")
    end
  end

  describe ".replace" do
    it "broadcasts the classic partial to the base stream and the v2 variant to the parallel stream" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("server-list", target: "server-list", partial: "servers/list", locals: {})
      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
        .with("server-list", :v2, target: "server-list", partial: "servers/list", locals: {}, variants: [ :v2 ])

      described_class.replace("server-list", target: "server-list", partial: "servers/list", locals: {})
    end
  end

  describe ".update" do
    it "passes a pre-rendered html payload through to both streams unchanged" do
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with("s", target: "t", html: "x")
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
        .with("s", :v2, target: "t", html: "x")

      described_class.update("s", target: "t", html: "x")
    end
  end
end
