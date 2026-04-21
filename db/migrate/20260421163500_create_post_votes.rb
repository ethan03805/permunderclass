class CreatePostVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :post_votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true
      t.integer :value, null: false

      t.timestamps
    end

    add_index :post_votes, [ :user_id, :post_id ], unique: true
  end
end
