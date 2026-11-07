# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StripeOrder do
  let(:order) { create(:stripe_order) }

  describe '#create_payment_intent' do
    it 'creates a payment intent with stripe' do
      VCR.use_cassette('stripe_payment_intent_success') do
        result = order.create_payment_intent('pm_card_visa')
        expect(result[:success]).to be true
        expect(result[:gift]).to be false
        expect(result[:voucher]).to be_nil
      end
    end

    it 'handles card errors' do
      VCR.use_cassette('stripe_payment_intent_error') do
        allow(Stripe::PaymentIntent).to receive(:create).and_raise(Stripe::CardError.new('Card declined', {}))
        result = order.create_payment_intent('pm_card_declined')
        expect(result[:error]).to eq('Card declined')
      end
    end
  end

  describe '#confirm_payment' do
    it 'confirms a payment intent' do
      VCR.use_cassette('stripe_payment_intent_confirm_success') do
        allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(double(status: 'succeeded'))
        result = order.confirm_payment('pi_123')
        expect(result[:success]).to be true
        expect(result[:gift]).to be false
        expect(result[:voucher]).to be_nil
      end
    end

    it 'handles confirmation errors' do
      VCR.use_cassette('stripe_payment_intent_confirm_error') do
        allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(double(status: 'requires_payment_method'))
        result = order.confirm_payment('pi_123')
        expect(result[:error]).to include('Payment confirmation failed')
      end
    end

    it 'confirms an intent that still requires confirmation' do
      intent = double(status: 'requires_confirmation')
      allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(intent)
      expect(intent).to receive(:confirm) { allow(intent).to receive(:status).and_return('succeeded') }

      result = order.confirm_payment('pi_123')

      expect(result[:success]).to be true
      expect(order.reload.status).to eq('Completed')
    end

    it 'reports the status when confirming does not succeed' do
      intent = double(status: 'requires_confirmation', confirm: nil)
      allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(intent)

      result = order.confirm_payment('pi_123')

      expect(result).to eq(error: 'Payment confirmation failed', status: 'requires_confirmation')
      expect(order.reload.status).not_to eq('Completed')
    end

    it 'returns card errors' do
      allow(Stripe::PaymentIntent).to receive(:retrieve).and_raise(Stripe::CardError.new('Card declined', {}))

      expect(order.confirm_payment('pi_123')).to eq(error: 'Card declined')
    end
  end

  describe '#create_express_payment_intent' do
    it 'stores the payment id and returns the client secret' do
      allow(Stripe::PaymentIntent).to receive(:create).and_return(double(id: 'pi_express', client_secret: 'secret'))

      result = order.create_express_payment_intent

      expect(result).to eq(client_secret: 'secret', payment_intent_id: 'pi_express')
      expect(order.reload.payment_id).to eq('pi_express')
    end

    it 'returns stripe errors' do
      allow(Stripe::PaymentIntent).to receive(:create).and_raise(Stripe::APIConnectionError.new('down'))

      expect(order.create_express_payment_intent).to eq(error: 'down')
    end
  end
end
