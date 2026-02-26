# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Api::CloudServersController do
  let(:reservation) { create(:reservation) }
  let(:callback_token) { SecureRandom.hex(32) }
  let(:cloud_server) { create(:cloud_server, cloud_status: 'provisioning', cloud_reservation_id: reservation.id, cloud_callback_token: callback_token) }

  describe 'POST #ready' do
    context 'with ssh_ready status' do
      it 'sets cloud_status to ssh_ready and enqueues ReservationWorker' do
        ReservationWorker.should_receive(:perform_async).with(reservation.id, 'start')
        request.headers['X-Callback-Token'] = callback_token
        post :ready, params: { id: cloud_server.id, status: 'ssh_ready' }

        expect(response).to have_http_status(:ok)
        expect(cloud_server.reload.cloud_status).to eq('ssh_ready')
      end
    end

    context 'with tf2_ready status' do
      it 'marks the cloud server ready and starts rcon polling' do
        expect(CloudServerRconPollWorker).to receive(:perform_async).with(reservation.id)
        request.headers['X-Callback-Token'] = callback_token
        post :ready, params: { id: cloud_server.id, status: 'tf2_ready' }

        expect(response).to have_http_status(:ok)
        expect(cloud_server.reload.cloud_status).to eq('ready')
        expect(reservation.reload.provisioned).to eq(false)
      end

      it 'does not start rcon polling if reservation is already provisioned' do
        reservation.update_columns(provisioned: true)
        expect(CloudServerRconPollWorker).not_to receive(:perform_async)
        request.headers['X-Callback-Token'] = callback_token
        post :ready, params: { id: cloud_server.id, status: 'tf2_ready' }

        expect(response).to have_http_status(:ok)
      end
    end

    it 'returns unauthorized with missing token' do
      post :ready, params: { id: cloud_server.id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized with wrong token' do
      request.headers['X-Callback-Token'] = 'wrong-token'
      post :ready, params: { id: cloud_server.id }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns not found for non-existent server' do
      request.headers['X-Callback-Token'] = callback_token
      post :ready, params: { id: 999999 }

      expect(response).to have_http_status(:not_found)
    end
  end
end
