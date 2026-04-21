class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :users do |t|
      t.citext :pseudonym, null: false
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 0
      t.integer :state, null: false, default: 0
      t.datetime :email_verified_at
      t.boolean :reply_alerts_enabled, null: false, default: true

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :pseudonym, unique: true
  end
end
