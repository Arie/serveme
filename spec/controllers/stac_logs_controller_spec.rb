# typed: false
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StacLogsController do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:reservation) { create(:reservation) }
  let(:stac_log) { create(:stac_log, reservation: reservation) }

  describe '#index' do
    it 'requires admin' do
      get :index
      expect(response).to redirect_to('/sessions/new')
    end

    it 'shows logs to admin' do
      sign_in(admin)
      get :index
      expect(response).to be_successful
    end
  end
end
