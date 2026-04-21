class CreateModeratorActions < ActiveRecord::Migration[8.1]
  def change
    create_table :moderator_actions do |t|
      t.references :moderator, null: false, foreign_key: { to_table: :users }
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.integer :action_type, default: 0, null: false
      t.text :public_note, default: "", null: false
      t.text :internal_note, default: "", null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :moderator_actions, [ :target_type, :target_id ]
    add_index :moderator_actions, [ :moderator_id, :created_at ]
  end
end
