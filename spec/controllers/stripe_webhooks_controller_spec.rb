# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StripeWebhooksController do
  describe '#create' do
    it 'returns 400 when the webhook signature is invalid' do
      allow(Stripe::Webhook).to receive(:construct_event).and_raise(
        Stripe::SignatureVerificationError.new("invalid signature", "sig_header")
      )

      post :create, body: '{}', as: :json

      expect(response.status).to eq(400)
    end

    it 'returns 400 when the payload is invalid JSON' do
      allow(Stripe::Webhook).to receive(:construct_event).and_raise(
        JSON::ParserError.new("unexpected token")
      )

      post :create, body: 'not json', as: :json

      expect(response.status).to eq(400)
    end
  end
end
