# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Api::MapsController do
  render_views

  describe '#index' do
    it 'renders a json with available maps' do
      allow(MapUpload).to receive(:available_maps).and_return([ 'cp_badlands', 'cp_granary', 'koth_viaduct' ])

      get :index, format: :json

      json = {
        maps: [ 'cp_badlands', 'cp_granary', 'koth_viaduct' ]
      }

      expect(response.body).to match_json_expression(json)
      expect(response.status).to eq(200)
    end

    it 'returns an empty array when no maps are available' do
      allow(MapUpload).to receive(:available_maps).and_return([])

      get :index, format: :json

      json = {
        maps: []
      }

      expect(response.body).to match_json_expression(json)
      expect(response.status).to eq(200)
    end

    it 'does not require authentication' do
      get :index, format: :json

      expect(response.status).not_to eq(401)
      expect(response.status).to eq(200)
    end
  end
end
