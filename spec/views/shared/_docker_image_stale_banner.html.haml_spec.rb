# typed: false
# frozen_string_literal: true

require "spec_helper"

describe "shared/_docker_image_stale_banner" do
  it "shows a banner when the docker image is stale" do
    allow(DockerImageReadiness).to receive(:stale?).and_return(true)

    render

    expect(rendered).to include("temporarily unavailable")
  end

  it "renders nothing when the docker image is current" do
    allow(DockerImageReadiness).to receive(:stale?).and_return(false)

    render

    expect(rendered).to be_blank
  end
end
