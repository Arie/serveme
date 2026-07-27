# typed: false
# frozen_string_literal: true

require 'spec_helper'

# SDR exists to hide a server's real address. Nothing we hand to a consumer may
# contain it for an sdr? server.
RSpec.describe 'SDR real address privacy' do
  let(:real_host) { 'secret-box.fakkelbrigade.eu' }
  let(:real_ip)   { '203.0.113.77' }
  let(:sdr_ip)    { '169.254.1.59' }
  let(:sdr_port)  { 4656 }

  let(:server) do
    s = create(:server, name: 'SDR Server', ip: real_host, port: '27015', tv_port: '27020',
                        sdr: true, last_sdr_ip: sdr_ip, last_sdr_port: sdr_port, last_sdr_tv_port: sdr_port + 1)
    s.update_column(:resolved_ip, real_ip)
    s
  end

  define_method(:expect_no_leak) do |payload|
    blob = payload.to_json
    expect(blob).not_to include(real_ip)
    expect(blob).not_to include(real_host)
    expect(blob).to include(sdr_ip)
  end

  it 'keeps the real address out of the server json partial' do
    json = JSON.parse(ApplicationController.render(
      partial: 'servers/server',
      formats: [ :json ],
      locals: { server: server }
    ))

    expect_no_leak(json)
  end

  it 'keeps the real address out of the reservation api payload' do
    reservation = create(:reservation, user: create(:user), server: server, password: 'foo', tv_password: 'bar')
    reservation.update_columns(sdr_ip: sdr_ip, sdr_port: sdr_port, sdr_tv_port: sdr_port + 1)

    json = JSON.parse(ApplicationController.render(
      partial: 'api/reservations/reservation',
      formats: [ :json ],
      locals: { reservation: reservation.reload }
    ))

    expect_no_leak(json)
  end

  it 'keeps the real address out of MCP list_servers' do
    server
    result = Mcp::Tools::ListServersTool.new(create(:user, :admin)).execute({})

    expect_no_leak(result)
  end

  it 'keeps the real address out of MCP get_reservation_status' do
    user = create(:user, :admin)
    reservation = create(:reservation, user: user, server: server, password: 'foo')
    reservation.update_columns(sdr_ip: sdr_ip, sdr_port: sdr_port, sdr_tv_port: sdr_port + 1)

    result = Mcp::Tools::GetReservationStatusTool.new(user).execute(reservation_id: reservation.id)

    expect_no_leak(result)
  end
end
