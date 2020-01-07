# frozen_string_literal: true

require 'spec_helper'

describe StripeOrder do
  let(:order) { create(:stripe_order, payer_id: 'src_here') }

  it 'captures a charge with stripe', :vcr do
    expect(order.charge).to eql 'succeeded'
    expect(order.reload.status).to eql 'Completed'
  end

  it 'deals with card errors', :vcr do
    expect(order.charge).to eql 'Your card was declined.'
    expect(order.reload.status).not_to eql 'Completed'
  end
end
