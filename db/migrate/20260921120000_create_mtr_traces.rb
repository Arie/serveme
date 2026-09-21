# frozen_string_literal: true

class CreateMtrTraces < ActiveRecord::Migration[8.1]
  def change
    create_table :mtr_traces do |t|
      t.string :target, null: false
      t.string :target_ip, null: false
      t.integer :cycles, null: false, default: 10
      t.references :user, foreign_key: true
      t.timestamps
      t.index :created_at
    end

    create_table :mtr_runs do |t|
      t.references :mtr_trace, null: false, foreign_key: true
      t.string :source_type, null: false
      t.string :source_key, null: false
      t.string :source_label, null: false
      t.string :source_detail
      t.string :source_flag
      t.string :status, null: false, default: "queued"
      t.jsonb :hops, null: false, default: []
      t.text :raw_output, null: false, default: ""
      t.string :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
  end
end
