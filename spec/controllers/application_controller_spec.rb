require 'spec_helper'

describe ApplicationController do

  controller(PagesController) do
    def index
      render :text => "foo"
    end
  end

  context "with an invalid time zone cookie" do
    it "falls back to the default time zone" do
      cookies[:time_zone] = "Etc/GMT 2"
      Time.should_receive(:zone=).with("Etc/GMT 2").and_call_original
      Time.should_receive(:zone=).with(Rails.configuration.time_zone).and_call_original
      get :index
    end
  end

  context "with a valid time zone" do
    it "changes the time zone" do
      time_zone_before_request = Time.zone
      cookies[:time_zone] = "Europe/Amsterdam"
      Time.should_receive(:zone=).with("Europe/Amsterdam").twice
      get :index
    end
  end
end
