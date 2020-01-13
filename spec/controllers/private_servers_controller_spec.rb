# frozen_string_literal: true

require 'spec_helper'

describe PrivateServersController do
  before do
    @user = create :user
    sign_in @user
  end

  describe '#create' do
    it "redirects to root for users that aren't a private server user" do
      post :create
      response.should redirect_to root_path
    end
  end
end
