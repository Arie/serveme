# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Admin::MapsController do
  render_views

  let(:admin_user) { create :user, :admin }
  let(:regular_user) { create :user }
  let(:map_uploader) { create :user, nickname: 'MapMaker' }

  before do
    sign_in admin_user
  end

  describe '#index' do
    let(:mock_bucket_objects) do
      [
        {
          key: 'maps/cp_badlands.bsp',
          map_name: 'cp_badlands',
          size: 1024000,
          uploader: map_uploader,
          upload_date: 1.day.ago
        },
        {
          key: 'maps/cp_granary.bsp',
          map_name: 'cp_granary',
          size: 2048000,
          uploader: nil,
          upload_date: nil
        }
      ]
    end

    let(:mock_map_statistics) do
      {
        'cp_badlands' => {
          times_played: 5,
          first_played: 1.week.ago,
          last_played: 1.day.ago
        }
      }
    end

    before do
      allow(MapUpload).to receive(:bucket_objects).and_return(mock_bucket_objects)
      allow(MapUpload).to receive(:map_statistics).and_return(mock_map_statistics)
    end

    context 'for admin users' do
      it 'renders the index page successfully' do
        get :index
        expect(response).to be_successful
        expect(response).to render_template(:index)
        expect(response.body).to include('cp_badlands')
        expect(response.body).to include('cp_granary')
        expect(response.body).to include(map_uploader.nickname)
        expect(response.body).to include('Unknown')
      end
    end

    context 'for non-admin users' do
      before do
        sign_in regular_user
      end

      it 'redirects to root for non-admins' do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe '#destroy' do
    let(:map_name) { 'cp_testmap' }

    before do
      allow(MapUpload).to receive(:delete_bucket_object)
    end

    context 'for admin users' do
      it 'deletes the map and redirects with success message' do
        delete :destroy, params: { id: map_name }

        expect(MapUpload).to have_received(:delete_bucket_object).with(map_name)
        expect(response).to redirect_to(admin_maps_path)
        expect(flash[:notice]).to eq("Map #{map_name} deleted")
      end
    end
  end
end
