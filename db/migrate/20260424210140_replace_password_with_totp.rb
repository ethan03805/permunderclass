class ReplacePasswordWithTotp < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :password_digest, :string, null: false

    add_column :users, :totp_secret, :text
    add_column :users, :totp_candidate_secret, :text
    add_column :users, :totp_candidate_secret_expires_at, :datetime
    add_column :users, :totp_last_used_counter, :bigint
    add_column :users, :sessions_generation, :integer, default: 0, null: false
    add_column :users, :enrollment_token_generation, :integer, default: 0, null: false
  end
end
