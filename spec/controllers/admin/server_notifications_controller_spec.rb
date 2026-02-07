# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ServerNotificationsController, type: :controller do
  # Assuming Group.admin_group exists and assigns admin privileges
  let(:admin_user) { create(:user, :admin) } # Use the :admin trait from user factory
  let(:user) { create(:user) }
  let(:server_notification1) { ServerNotification.create!(message: "Test Notification 1", notification_type: "public") }
  let(:server_notification2) { ServerNotification.create!(message: "Test Ad 1", notification_type: "ad") }

  before(:each) do
    # Stub new_user_session_path if it remains problematic, or ensure it's loaded via Devise/Rails helpers
    # allow(controller).to receive(:new_user_session_path).and_return('/sessions/new')
  end

  shared_examples "admin access only" do |action, http_method, params = {}|
    context "when not logged in" do
      it "redirects to login page" do
        send(http_method, action, params: params)
        expect(response).to redirect_to("/sessions/new") # Use direct path
      end
    end

    context "when logged in as a non-admin user" do
      before { sign_in user }
      it "redirects to root path" do
        send(http_method, action, params: params)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET #index" do
    it_behaves_like "admin access only", :index, :get

    context "when logged in as an admin" do
      before { sign_in admin_user }

      context "rendering views" do
        render_views

        it "assigns all server_notifications to @server_notifications and renders the index template" do
          # Trigger creation of notifications before request
          server_notification1
          server_notification2
          get :index
          expect(assigns(:server_notifications)).to match_array([ server_notification1, server_notification2 ])
          expect(response).to render_template(:index)
          expect(response.body).to include("Test Notification 1")
          expect(response.body).to include("Test Ad 1")
        end
      end
    end
  end

  describe "POST #create" do
    it_behaves_like "admin access only", :create, :post, { server_notification: { message: "New", notification_type: "public" } }

    context "when logged in as an admin" do
      before { sign_in admin_user }

      context "with valid parameters" do
        let(:valid_attributes) { { message: "Shiny New Notification", notification_type: "public" } }

        it "creates a new ServerNotification" do
          expect {
            post :create, params: { server_notification: valid_attributes }
          }.to change(ServerNotification, :count).by(1)
        end

        it "redirects to the server_notifications index with a notice" do
          post :create, params: { server_notification: valid_attributes }
          expect(response).to redirect_to(admin_server_notifications_path)
          expect(flash[:notice]).to eq("Server notification was successfully created.")
        end
      end

      context "with invalid parameters" do
        let(:invalid_attributes) { { message: "", notification_type: "public" } }

        it "does not create a new ServerNotification" do
          expect {
            post :create, params: { server_notification: invalid_attributes }
          }.not_to change(ServerNotification, :count)
        end

        it "re-renders the 'index' template with existing notifications and the new unsaved notification" do
          # Trigger creation of notifications before request
          server_notification1
          server_notification2
          post :create, params: { server_notification: invalid_attributes }
          expect(response).to render_template(:index)
          expect(assigns(:server_notifications)).to match_array([ server_notification1, server_notification2 ])
          expect(assigns(:server_notification)).to be_a_new(ServerNotification)
          expect(assigns(:server_notification).errors).not_to be_empty
        end
      end
    end
  end

  describe "PATCH #update" do
    let(:notification_to_update) { ServerNotification.create!(message: "Old Message", notification_type: "public") }
    it_behaves_like "admin access only", :update, :patch, { id: 0, server_notification: { message: "Update" } }

    context "when logged in as an admin" do
      before { sign_in admin_user }

      context "with valid parameters" do
        let(:new_attributes) { { message: "Updated Message successfully" } }

        it "updates the requested server_notification" do
          patch :update, params: { id: notification_to_update.id, server_notification: new_attributes }
          notification_to_update.reload
          expect(notification_to_update.message).to eq("Updated Message successfully")
        end

        it "redirects to the server_notifications index with a notice" do
          patch :update, params: { id: notification_to_update.id, server_notification: new_attributes }
          expect(response).to redirect_to(admin_server_notifications_path)
          expect(flash[:notice]).to eq("Server notification was successfully updated.")
        end
      end

      context "with invalid parameters" do
        let(:invalid_attributes) { { message: "" } }

        it "does not update the server_notification" do
          original_message = notification_to_update.message
          patch :update, params: { id: notification_to_update.id, server_notification: invalid_attributes }
          notification_to_update.reload
          expect(notification_to_update.message).to eq(original_message)
        end

        it "re-renders the 'index' template with errors" do
          # Trigger creation of notifications before request
          server_notification1
          server_notification2
          patch :update, params: { id: notification_to_update.id, server_notification: invalid_attributes }
          expect(response).to render_template(:index)
          expect(assigns(:server_notification).errors).not_to be_empty
          all_notifications = ([ server_notification1, server_notification2, notification_to_update ]).uniq(&:id).sort_by(&:id)
          expect(assigns(:server_notifications).map(&:id).sort).to eq(all_notifications.map(&:id).sort)
        end
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:notification_to_delete) { ServerNotification.create!(message: "To Be Deleted", notification_type: "public") }
    it_behaves_like "admin access only", :destroy, :delete, { id: 0 } # Placeholder ID

    context "when logged in as an admin" do
      before { sign_in admin_user }

      it "destroys the requested server_notification" do
        expect {
          delete :destroy, params: { id: notification_to_delete.id }
        }.to change(ServerNotification, :count).by(-1)
      end

      it "redirects to the server_notifications list with a notice" do
        delete :destroy, params: { id: notification_to_delete.id }
        expect(response).to redirect_to(admin_server_notifications_path) # Changed from _url to _path
        expect(flash[:notice]).to eq("Server notification was successfully destroyed.")
      end
    end
  end
end
