# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe ServersController do
  before do
    @user = create :user
    @user.groups << Group.donator_group
    sign_in @user
  end

  describe '#index' do
    it 'should assign the servers variable' do
      first   = create :server, name: 'abc'
      third   = create :server, name: 'efg'
      second  = create :server, name: 'bcd'
      reservation = create :reservation, server: first
      _stat = create :server_statistic, server: first, reservation: reservation, created_at: 1.minute.ago
      get :index
      expect(assigns(:servers).map(&:name)).to eq([ first.name, second.name, third.name ])
      expect(response).to be_successful
    end
  end
end
