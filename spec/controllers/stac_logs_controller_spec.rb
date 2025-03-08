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

  describe '#show' do
    it 'requires admin' do
      get :show, params: { id: stac_log.id }
      expect(response).to redirect_to('/sessions/new')
    end

    it 'shows log to admin' do
      sign_in(admin)
      get :show, params: { id: stac_log.id }
      expect(response).to be_successful
    end
  end

  describe '#notify' do
    it 'requires admin' do
      post :notify, params: { id: stac_log.id }
      expect(response).to redirect_to('/sessions/new')
    end

    it 'processes log and sends notification' do
      sign_in(admin)
      processor = instance_double(StacLogProcessor)
      expect(StacLogProcessor).to receive(:new).with(stac_log.reservation).and_return(processor)
      expect(processor).to receive(:process_content).with(stac_log.contents)

      post :notify, params: { id: stac_log.id }
      expect(response).to redirect_to(stac_logs_path)
      expect(flash[:notice]).to eq('Discord notification sent')
    end
  end
end
