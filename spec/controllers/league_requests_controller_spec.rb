require 'spec_helper'

describe LeagueRequestsController do
  render_views

  before do
    @user = create :user
    sign_in @user
  end

  describe '#new' do
    context 'for non-admins' do
      it 'redirect to root for non admins' do
        get :new

        response.should redirect_to(root_path)
      end
    end

    context 'for admins' do
      it 'shows the search form' do
        @user.groups << Group.admin_group

        get :new

        assigns(:results).should be_nil
      end
    end
  end
end
