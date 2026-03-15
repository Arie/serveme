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

    it 'renders a sorted plain text list of available maps' do
      allow(MapUpload).to receive(:available_maps).and_return([ 'koth_viaduct', 'cp_badlands', 'cp_granary' ])
      Rails.cache.delete("api_maps_text")

      get :index, format: :txt

      expect(response.status).to eq(200)
      expect(response.content_type).to include('text/plain')
      expect(response.body).to eq("cp_badlands\ncp_granary\nkoth_viaduct")
    end

    it 'returns an empty body when no maps are available in text format' do
      allow(MapUpload).to receive(:available_maps).and_return([])
      Rails.cache.delete("api_maps_text")

      get :index, format: :txt

      expect(response.status).to eq(200)
      expect(response.content_type).to include('text/plain')
      expect(response.body).to eq('')
    end
  end
end
