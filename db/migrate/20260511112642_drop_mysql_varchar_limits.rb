# typed: true
# frozen_string_literal: true

class DropMysqlVarcharLimits < ActiveRecord::Migration[8.1]
  COLUMNS = [
    [ :groups,                :name ],
    [ :paypal_orders,         :payer_id ],
    [ :paypal_orders,         :payment_id ],
    [ :paypal_orders,         :status ],
    [ :reservation_players,   :ip ],
    [ :reservation_players,   :name ],
    [ :reservation_players,   :steam_uid ],
    [ :reservation_statuses,  :status ],
    [ :reservations,          :logsecret ],
    [ :server_notifications,  :message ],
    [ :server_notifications,  :notification_type ],
    [ :server_statistics,     :map_name ],
    [ :users,                 :api_key ],
    [ :users,                 :current_sign_in_ip ],
    [ :users,                 :email ],
    [ :users,                 :encrypted_password ],
    [ :users,                 :last_sign_in_ip ],
    [ :users,                 :name ],
    [ :users,                 :nickname ],
    [ :users,                 :provider ],
    [ :users,                 :reset_password_token ],
    [ :users,                 :uid ]
  ].freeze

  # The legacy paper_trail `versions` table still exists on AU/SEA (empty,
  # gem long removed) but is not in db/schema.rb. Strip its varchar limits
  # in-place if the table is still around — separate from this migration's
  # core target, but cheap to clean up while we're here.
  LEGACY_VERSIONS_COLUMNS = %i[event item_type whodunnit].freeze

  def up
    COLUMNS.each do |table, column|
      change_column table, column, :text
    end

    if table_exists?(:versions)
      LEGACY_VERSIONS_COLUMNS.each { |column| change_column :versions, column, :text }
    end
  end

  def down
    # No-op: schema.rb already declares these as :string with no limit,
    # so the regions that ran this migration are now aligned with schema.rb.
    # The original MySQL-era limits (191/64/32) were never enforced in code
    # and are not worth reinstating.
  end
end
