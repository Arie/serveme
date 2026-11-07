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

    context 'with a verified event' do
      let(:user) { create(:user) }
      let(:product) { create(:product) }
      let!(:order) { create(:stripe_order, user: user, product: product, payment_id: 'pi_123') }

      let(:deliver) do
        lambda do |type, payment_id = 'pi_123'|
          event = Stripe::Event.construct_from(type: type, data: { object: { id: payment_id } })
          allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
          post :create, body: '{}', as: :json
        end
      end

      it 'completes the order and grants perks on payment_intent.succeeded' do
        deliver.call('payment_intent.succeeded')

        expect(response.status).to eq(200)
        expect(order.reload.status).to eq('Completed')
        expect(user.reload).to be_donator
      end

      it 'does not grant perks again for an already completed order' do
        order.update!(status: 'Completed')
        expect(GrantPerks).not_to receive(:new)

        deliver.call('payment_intent.succeeded')

        expect(response.status).to eq(200)
      end

      it 'marks the order failed on payment_intent.payment_failed' do
        deliver.call('payment_intent.payment_failed')

        expect(response.status).to eq(200)
        expect(order.reload.status).to eq('Failed')
      end

      it 'ignores events for unknown payment intents' do
        deliver.call('payment_intent.succeeded', 'pi_unknown')

        expect(response.status).to eq(200)
        expect(order.reload.status).not_to eq('Completed')
      end

      it 'ignores other event types' do
        deliver.call('charge.refunded')

        expect(response.status).to eq(200)
        expect(order.reload.status).to be_nil
      end
    end

    it 'verifies with the region specific secret' do
      stub_const('SITE_HOST', 'na.serveme.tf')
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:stripe, :na_wh_secret).and_return('whsec_na')
      expect(Stripe::Webhook).to receive(:construct_event).with(anything, anything, 'whsec_na').at_least(:once)
        .and_return(Stripe::Event.construct_from(type: 'ping', data: { object: {} }))

      post :create, body: '{}', as: :json

      expect(response.status).to eq(200)
    end
  end
end
