# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe BetaUi, type: :controller do
  controller(ApplicationController) do
    # Skip filters that would redirect/short-circuit the bare test action.
    skip_before_action :authenticate_user!, raise: false
    skip_before_action :redirect_if_country_banned, raise: false
    skip_before_action :store_current_location, raise: false
    skip_before_action :authorize_mini_profiler, raise: false

    define_method(:index) do
      render plain: "ok"
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }
  end

  context "without the ui_v2 cookie" do
    it "does not enable the v2 variant or layout" do
      get :index
      expect(controller.send(:beta_ui?)).to be false
      expect(controller.send(:resolve_layout)).to be_nil
      expect(request.variant).not_to include(:v2)
    end
  end

  context "with the ui_v2 cookie on an action without a +v2 template" do
    it "reports beta but does not switch variant/layout" do
      allow(BetaUi).to receive(:v2_redesigned?).and_return(false)
      request.cookies["ui_v2"] = "true"
      get :index
      expect(controller.send(:beta_ui?)).to be true
      expect(controller.send(:resolve_layout)).to be_nil
      expect(request.variant).not_to include(:v2)
    end
  end

  context "with the ui_v2 cookie on an action that has a +v2 template" do
    it "enables the v2 variant and the v2 layout" do
      allow(BetaUi).to receive(:v2_redesigned?).with("anonymous", "index").and_return(true)
      request.cookies["ui_v2"] = "true"
      get :index
      expect(request.variant).to include(:v2)
      expect(controller.send(:resolve_layout)).to eq("application_v2")
    end
  end

  describe ".v2_redesigned?" do
    it "detects the real welcome +v2 template via the filesystem scan" do
      expect(BetaUi.v2_redesigned?("pages", "welcome")).to be true
      expect(BetaUi.v2_redesigned?("pages", "definitely_not_a_page")).to be false
    end
  end
end
