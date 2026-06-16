# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe BetaController do
  describe "#show" do
    it "renders for logged-out users" do
      get :show
      expect(response).to be_successful
    end
  end

  describe "#enable" do
    it "sets the ui_v2 cookie and redirects to root" do
      post :enable
      expect(response.cookies["ui_v2"]).to eq("true")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "#disable" do
    it "clears the ui_v2 cookie and redirects to root" do
      request.cookies["ui_v2"] = "true"
      delete :disable
      expect(response.cookies["ui_v2"]).to be_nil
      expect(response).to redirect_to(root_path)
    end
  end
end
