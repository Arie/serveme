# typed: false
# frozen_string_literal: true

require "spec_helper"

describe "shared/_tf2_update_banner" do
  it "shows a banner when the docker image is stale" do
    allow(DockerImageReadiness).to receive(:stale?).and_return(true)

    render

    expect(rendered).to include("TF2 update was just released")
  end

  it "renders nothing when the docker image is current" do
    allow(DockerImageReadiness).to receive(:stale?).and_return(false)

    render

    expect(rendered).to be_blank
  end
end
