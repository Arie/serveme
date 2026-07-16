# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe Api::ReservationsController, "N+1 queries on #index", type: :controller do
  render_views

  before do
    @api_user = create :user
    @api_user.groups << Group.admin_group
    controller.stub(api_user: @api_user)
  end

  # Count application-level SQL queries, ignoring schema/transaction noise.
  define_method(:count_index_queries) do
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA"
      next if payload[:sql] =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i

      queries << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get :index, params: { limit: 500, offset: 0 }, format: :json
    end
    expect(response.status).to eql 200
    queries.size
  end

  define_method(:create_ended_reservation) do
    reservation = create(:reservation, ended: true, user: create(:user))
    create(:reservation_status, reservation: reservation)
    LogUpload.create!(reservation: reservation, url: "https://logs.tf/#{reservation.id}", status: "TFTrue upload")
    reservation
  end

  it "does not add per-row queries as the number of reservations grows" do
    2.times { create_ended_reservation }
    baseline = count_index_queries

    # Add three more rows. With proper eager loading the association loads are
    # constant per request, so adding rows must not add per-row queries.
    3.times { create_ended_reservation }
    grown = count_index_queries

    added_rows = 3
    # Each un-eager-loaded association (user, reservation_statuses, log_uploads)
    # would add one query per row; assert we stay well under that.
    expect(grown - baseline).to be <= 2,
      "index queries scaled with row count (#{baseline} -> #{grown} for #{added_rows} more rows), indicating an N+1"
  end
end
