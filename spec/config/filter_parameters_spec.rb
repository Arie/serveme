# typed: false
# frozen_string_literal: true

require "spec_helper"

describe "filter_parameters configuration" do
  # Assert on filtering behaviour rather than the raw array: depending on load
  # order the app may compile config.filter_parameters into regexps, so checking
  # for literal symbols is brittle. The ParameterFilter is what actually scrubs logs.
  subject(:param_filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  it "filters password from request logs" do
    expect(param_filter.filter("password" => "hunter2")).to eq("password" => "[FILTERED]")
  end

  it "filters api_key from request logs" do
    expect(param_filter.filter("api_key" => "secret-key")).to eq("api_key" => "[FILTERED]")
  end
end
