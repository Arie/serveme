# typed: false
# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

describe CloudflareCachePurge do
  let(:purger) { described_class.new }
  let(:url) { "https://api.cloudflare.com/client/v4/zones/zone-1/purge_cache" }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:cloudflare, :dns_zone_id).and_return("zone-1")
    allow(Rails.application.credentials).to receive(:dig).with(:cloudflare, :dns_api_token).and_return("token-1")
  end

  it "purges the given urls" do
    request = stub_request(:post, url)
              .with(body: { files: [ "https://fastdl.serveme.tf/maps/cp_badlands.bsp" ] }.to_json,
                    headers: { "Authorization" => "Bearer token-1" })
              .to_return(body: { success: true }.to_json)

    purger.purge([ "https://fastdl.serveme.tf/maps/cp_badlands.bsp" ])

    expect(request).to have_been_requested
  end

  it "splits the urls over several calls, because Cloudflare takes 30 at a time" do
    request = stub_request(:post, url).to_return(body: { success: true }.to_json)

    purger.purge(Array.new(31) { |i| "https://fastdl.serveme.tf/maps/map#{i}.bsp" })

    expect(request).to have_been_requested.twice
  end

  it "raises when Cloudflare refuses the purge" do
    stub_request(:post, url).to_return(body: { success: false, errors: [ { message: "Authentication error" } ] }.to_json)

    expect { purger.purge([ "https://fastdl.serveme.tf/maps/cp_badlands.bsp" ]) }
      .to raise_error(CloudflareCachePurge::Error, /Authentication error/)
  end

  it "does nothing without urls" do
    purger.purge([])

    expect(a_request(:post, url)).not_to have_been_made
  end
end
