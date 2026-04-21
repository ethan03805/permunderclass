class RefineCoreDomainModels < ActiveRecord::Migration[8.1]
  def up
    change_column_default :posts, :post_type, from: 0, to: nil
    change_column_default :posts, :linter_flags, from: {}, to: []
    execute <<~SQL
      UPDATE posts
      SET published_at = COALESCE(published_at, created_at, CURRENT_TIMESTAMP),
          linter_flags = '[]'::jsonb
      WHERE published_at IS NULL OR linter_flags = '{}'::jsonb
    SQL
    change_column_null :posts, :published_at, false

    change_column_default :reports, :reason_code, from: 0, to: nil
    change_column_default :moderator_actions, :action_type, from: 0, to: nil
    change_column_default :moderator_actions, :public_note, from: "", to: nil
    change_column_default :moderator_actions, :internal_note, from: "", to: nil

    add_foreign_key :comments, :comments, column: :parent_id
    add_check_constraint :comments, "depth BETWEEN 0 AND 8", name: "comments_depth_range"
    add_check_constraint :post_votes, "value IN (1, -1)", name: "post_votes_value_range"
    add_check_constraint :comment_votes, "value IN (1, -1)", name: "comment_votes_value_range"
  end

  def down
    remove_check_constraint :comment_votes, name: "comment_votes_value_range"
    remove_check_constraint :post_votes, name: "post_votes_value_range"
    remove_check_constraint :comments, name: "comments_depth_range"
    remove_foreign_key :comments, column: :parent_id

    change_column_default :moderator_actions, :internal_note, from: nil, to: ""
    change_column_default :moderator_actions, :public_note, from: nil, to: ""
    change_column_default :moderator_actions, :action_type, from: nil, to: 0
    change_column_default :reports, :reason_code, from: nil, to: 0

    change_column_null :posts, :published_at, true
    execute <<~SQL
      UPDATE posts
      SET linter_flags = '{}'::jsonb
      WHERE linter_flags = '[]'::jsonb
    SQL
    change_column_default :posts, :linter_flags, from: [], to: {}
    change_column_default :posts, :post_type, from: nil, to: 0
  end
end
