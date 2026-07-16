# typed: false
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

    context "for a private server user" do
      before do
        @user.groups << Group.private_user(@user)
      end

      it "does not assign a server the user is not eligible for (IDOR)" do
        other_group = create :group
        ineligible_server = create :server, name: "Someone else's private server"
        create :group_server, group: other_group, server: ineligible_server

        post :create, params: { private_server: { server_id: ineligible_server.id } }

        @user.reload.private_server.should be_nil
        Group.private_user(@user).servers.should_not include(ineligible_server)
      end

      it "assigns an eligible (active, group-less) server" do
        eligible_server = create :server, name: "Free server", ip: "176.9.138.144"

        post :create, params: { private_server: { server_id: eligible_server.id } }

        @user.reload.private_server.should == eligible_server
      end
    end
  end
end
