require 'spec_helper'

describe Api::DonatorsController do

  render_views

  before do
    @user = create :user, uid: "12345"
    @user.groups << Group.admin_group
    controller.stub(:api_user => @user)
  end

  describe "#new" do

    it 'renders a json to be filled in' do
      get :new, format: :json
      json = {
        donator: {
          steam_uid: nil,
          expires_at: nil
        }.ignore_extra_keys!,
        actions: Hash
        }
      expect(response.body).to match_json_expression(json)
    end
  end

  describe "#create" do

    it "saves a valid donator and shows the results" do
      post :create, params: { donator: { steam_uid: @user.uid, expires_at: (Time.current + 1.month).to_s } }, format: :json
      json = {
        donator: {
          steam_uid: @user.uid,
          expires_at: String,
        }.ignore_extra_keys!,
      }
      expect(response.body).to match_json_expression(json)
      expect(Group.donator_group.group_users.where(user_id: @user.id).size).to eql 1
    end
  end

  describe "#destroy" do

    it "deletes a donator" do
      create :group_user, user_id: @user.id, group_id: Group.donator_group.id, expires_at: 1.month.from_now
      expect(Group.donator_group.group_users.where(user_id: @user.id).size).to eql 1

      delete :destroy, params: { id: @user.uid }, format: :json

      expect(response.status).to eql 204
      expect(Group.donator_group.group_users.where(user_id: @user.id).size).to eql 0
    end

    it "404s when user wasn't found" do
      delete :destroy, params: { id: "some-other-uid" }, format: :json
      expect(response.status).to eql 404
    end
  end

end
