class PostsController < ApplicationController
  before_action :require_verified_user!, except: :show
  before_action :set_post, only: [ :show, :edit, :update ]
  before_action :set_available_tags, only: [ :new, :create, :edit, :update ]
  before_action :require_post_author!, only: [ :edit, :update ]

  def new
    return render :type_picker unless selected_post_type.present?

    @post = current_user.posts.build(post_type: selected_post_type)
  end

  def create
    return render(:type_picker, status: :unprocessable_entity) unless selected_post_type.present?

    @selected_tag_ids = filtered_tag_ids
    @post = current_user.posts.build(post_params.except(:tag_ids))
    mirror_linter_flags
    selected_tags = selected_tags_for_assignment

    if @selected_tag_ids.size > Post::MAX_TAGS
      @post.errors.add(:tags, :too_many)
      return render :new, status: :unprocessable_entity
    end

    if @post.save
      @post.tags = selected_tags
      redirect_to post_path(@post), notice: t("posts.notices.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    rewrite_requested_recovery = @post.rewrite_requested?
    original_rewrite_reason = @post.rewrite_reason
    @selected_tag_ids = filtered_tag_ids

    @post.assign_attributes(post_params.except(:post_type, :tag_ids))
    republish_rewrite_requested_post if rewrite_requested_recovery
    mirror_linter_flags
    selected_tags = selected_tags_for_assignment

    if @selected_tag_ids.size > Post::MAX_TAGS
      @post.errors.add(:tags, :too_many)
      restore_rewrite_requested_state(original_rewrite_reason) if rewrite_requested_recovery
      return render :edit, status: :unprocessable_entity
    end

    if @post.save
      @post.tags = selected_tags
      notice_key = rewrite_requested_recovery ? "posts.notices.rewrite_recovered" : "posts.notices.updated"
      redirect_to post_path(@post), notice: t(notice_key)
    else
      restore_rewrite_requested_state(original_rewrite_reason) if rewrite_requested_recovery
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_post
    @post = Post.includes(:tags, :user, image_attachment: :blob, video_attachment: :blob).find_by_slugged_id!(params[:id])
    raise ActiveRecord::RecordNotFound unless @post.visible_to?(current_user)
  end

  def require_post_author!
    raise ActiveRecord::RecordNotFound unless @post.owned_by?(current_user)
  end

  def set_available_tags
    @available_tags = Tag.active.order(:name)
  end

  def selected_post_type
    return @selected_post_type if defined?(@selected_post_type)

    requested_type = params[:post_type].presence || params.dig(:post, :post_type).presence
    @selected_post_type = requested_type if Post.post_types.key?(requested_type)
  end

  def post_params
    params.fetch(:post, {}).permit(
      :post_type,
      :title,
      :body,
      :link_url,
      :build_status,
      :image,
      :video,
      :remove_image,
      :remove_video,
      tag_ids: []
    )
  end

  def mirror_linter_flags
    @post.linter_flags = HypeLinter.flags_for_post(@post)
  end

  def filtered_tag_ids
    Array(post_params[:tag_ids]).filter_map(&:presence).map(&:to_i)
  end

  def selected_tags_for_assignment
    selected_tags = Tag.active.where(id: @selected_tag_ids)
    preserved_archived_tags = @post.persisted? ? @post.tags.archived.to_a : []

    preserved_archived_tags + selected_tags
  end

  def republish_rewrite_requested_post
    @post.status = :published
    @post.rewrite_reason = nil
  end

  def restore_rewrite_requested_state(original_rewrite_reason)
    @post.status = :rewrite_requested
    @post.rewrite_reason = original_rewrite_reason
  end
end
