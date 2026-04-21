class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.bigint :parent_id
      t.integer :depth, default: 0, null: false
      t.text :body, null: false
      t.integer :status, default: 0, null: false
      t.integer :upvote_count, default: 0, null: false
      t.integer :downvote_count, default: 0, null: false
      t.integer :score, default: 0, null: false
      t.integer :reply_count, default: 0, null: false
      t.integer :report_count, default: 0, null: false
      t.datetime :edited_at

      t.timestamps
    end

    add_index :comments, :parent_id
    add_index :comments, :status
    add_index :comments, [ :post_id, :created_at ]
    add_index :comments, [ :parent_id, :created_at ]
  end
end
