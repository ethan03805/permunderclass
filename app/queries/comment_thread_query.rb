class CommentThreadQuery
  SORTS = %w[top new controversial].freeze

  def initialize(post:, sort: nil)
    @post = post
    @requested_sort = sort
  end

  def call
    comments = @post.comments.includes(:user).to_a
    comments_by_parent = comments.group_by(&:parent_id)

    comments_by_parent.each_value do |sibling_comments|
      sibling_comments.sort_by! { |comment| sort_key_for(comment) }
    end

    {
      comments_by_parent: comments_by_parent,
      comment_ids: comments.map(&:id),
      sort: sort
    }
  end

  def sort
    SORTS.include?(@requested_sort.to_s) ? @requested_sort.to_s : "top"
  end

  private

  def sort_key_for(comment)
    case sort
    when "new"
      [ -comment.created_at.to_f, -comment.id ]
    when "controversial"
      controversial_key_for(comment)
    else
      [ -comment.score.to_i, -comment.upvote_count.to_i, comment.created_at.to_f, comment.id ]
    end
  end

  def controversial_key_for(comment)
    total_votes = comment.upvote_count.to_i + comment.downvote_count.to_i
    eligible = total_votes >= 4
    controversy_score = total_votes.to_f / [ comment.score.to_i.abs, 1 ].max

    [
      eligible ? 0 : 1,
      eligible ? -controversy_score : 0,
      -comment.created_at.to_f,
      -comment.id
    ]
  end
end
