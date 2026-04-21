class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :post_type, default: 0, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.integer :status, default: 0, null: false
      t.datetime :published_at
      t.integer :upvote_count, default: 0, null: false
      t.integer :downvote_count, default: 0, null: false
      t.integer :score, default: 0, null: false
      t.integer :comment_count, default: 0, null: false
      t.decimal :hot_score, precision: 16, scale: 7, default: 0.0, null: false
      t.integer :report_count, default: 0, null: false
      t.jsonb :linter_flags, default: {}, null: false
      t.string :slug
      t.string :link_url
      t.integer :build_status
      t.datetime :rewrite_requested_at
      t.text :rewrite_reason
      t.datetime :edited_at

      t.timestamps
    end

    add_index :posts, :hot_score
    add_index :posts, :published_at
    add_index :posts, :status
    add_index :posts, :slug, unique: true
    add_index :posts, [ :post_type, :status ]
  end
end
