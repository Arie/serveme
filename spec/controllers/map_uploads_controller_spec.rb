# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe MapUploadsController do
  render_views

  describe '#index' do
    let(:mock_bucket_objects) do
      [
        {
          key: 'maps/cp_badlands.bsp',
          map_name: 'cp_badlands',
          size: 1024000,
          uploader: nil,
          upload_date: nil
        }
      ]
    end

    before do
      allow(MapUpload).to receive(:bucket_objects).and_return(mock_bucket_objects)
      allow(MapUpload).to receive(:map_statistics).and_return({})
    end

    it 'renders the index page for anonymous users' do
      get :index
      expect(response).to be_successful
      expect(response).to render_template(:index)
      expect(response.body).to include('cp_badlands')
    end

    it 'raises UnknownFormat for JSON requests' do
      expect do
        get :index, format: :json
      end.to raise_error(ActionController::UnknownFormat)
    end
  end
end
