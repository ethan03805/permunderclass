class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :reporter, null: false, foreign_key: { to_table: :users }
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.integer :reason_code, default: 0, null: false
      t.text :details
      t.integer :status, default: 0, null: false
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :reports, [ :target_type, :target_id ]
    add_index :reports, [ :reporter_id, :target_type, :target_id, :status ],
      unique: true,
      where: "status = 0",
      name: "index_reports_on_open_uniqueness"
  end
end
