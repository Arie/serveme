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
  end
end
