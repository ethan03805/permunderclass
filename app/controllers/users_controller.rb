class UsersController < ApplicationController
  PROFILE_PER_PAGE = 25
  PROFILE_ACTIVITIES = %w[posts comments].freeze

  before_action :require_signed_out_user!, only: %i[create new]
  before_action :require_authenticated_user!, only: :update_preferences
  before_action :set_profile_user, only: [ :show, :update_preferences ]

  def new
    @user = User.new(reply_alerts_enabled: true)
  end

  def show
    @activity = profile_activity
    @post_type = profile_post_type
    @result = @activity == "comments" ? profile_comments_result : profile_posts_result
    @records = @result[:records]
  end

  def create
    @user = User.new(user_params)
    spam_check_result = spam_check_result_for(:sign_up)

    unless spam_check_result.allowed?
      @user.errors.add(:base, spam_check_result.error_key)
      render :new, status: :unprocessable_entity
      return
    end

    unless turnstile_verified?
      @user.errors.add(:base, :turnstile_failed)
      render :new, status: :unprocessable_entity
      return
    end

    if @user.save
      start_session_for(@user)
      UserMailer.email_verification(@user).deliver_now

      redirect_to root_path, notice: t("auth.sign_up.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update_preferences
    raise ActiveRecord::RecordNotFound unless current_user == @profile_user

    if @profile_user.update(profile_preferences_params)
      redirect_to profile_path(@profile_user.pseudonym, anchor: "profile-preferences"), notice: t("profiles.preferences.updated")
    else
      redirect_to profile_path(@profile_user.pseudonym, anchor: "profile-preferences"), alert: @profile_user.errors.full_messages.to_sentence
    end
  end

  private

  def set_profile_user
    @profile_user = User.find_by!(pseudonym: params[:pseudonym].to_s.strip.downcase)
  end
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :pseudonym)
  end

  def profile_preferences_params
    params.require(:user).permit(:reply_alerts_enabled)
  end

  def profile_activity
    PROFILE_ACTIVITIES.include?(params[:view].to_s) ? params[:view].to_s : "posts"
  end

  def profile_post_type
    Post.post_types.key?(params[:post_type].to_s) ? params[:post_type].to_s : nil
  end

  def profile_posts_result
    scope = @profile_user.posts
      .where(status: visible_post_statuses)
      .includes(:tags)
      .order(published_at: :desc, id: :desc)

    scope = scope.where(post_type: @post_type) if @post_type.present?

    paginate(scope)
  end

  def profile_comments_result
    scope = @profile_user.comments
      .joins(:post)
      .includes(:post)
      .where(status: visible_comment_statuses, posts: { status: visible_post_statuses })
      .order(created_at: :desc, id: :desc)

    paginate(scope)
  end

  def visible_post_statuses
    current_user&.role.in?(%w[moderator admin]) ? Post.statuses.keys : %w[published rewrite_requested]
  end

  def visible_comment_statuses
    current_user&.role.in?(%w[moderator admin]) ? Comment.statuses.keys : [ "published" ]
  end

  def page
    [ params[:page].to_i, 1 ].max
  end

  def paginate(scope)
    total = scope.count
    offset = (page - 1) * PROFILE_PER_PAGE

    {
      records: scope.limit(PROFILE_PER_PAGE).offset(offset).to_a,
      total: total,
      page: page,
      per_page: PROFILE_PER_PAGE,
      total_pages: (total.to_f / PROFILE_PER_PAGE).ceil
    }
  end
end
