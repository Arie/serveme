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

  context "with the ui_v2 cookie on a non-redesigned action" do
    it "reports beta but does not switch variant/layout (action not allow-listed)" do
      request.cookies["ui_v2"] = "true"
      get :index
      expect(controller.send(:beta_ui?)).to be true
      expect(controller.send(:resolve_layout)).to be_nil
      expect(request.variant).not_to include(:v2)
    end
  end

  context "with the ui_v2 cookie on a redesigned action" do
    before do
      stub_const("BetaUi::REDESIGNED_ACTIONS", { "anonymous" => %w[index] })
    end

    it "enables the v2 variant and the v2 layout" do
      request.cookies["ui_v2"] = "true"
      get :index
      expect(request.variant).to include(:v2)
      expect(controller.send(:resolve_layout)).to eq("application_v2")
    end
  end
end
