module Mod
  class TagsController < BaseController
    before_action :set_tag, only: :update

    def index
      @new_tag = Tag.new
      @tags = Tag.includes(:posts).order(:state, :name)
      @recent_actions = ModeratorAction.where(target_type: "Tag").includes(:moderator, :target).order(created_at: :desc).limit(25)
    end

    def create
      tag = Tag.new(tag_params)

      ActiveRecord::Base.transaction do
        tag.save!
        ModeratorAction.create!(
          moderator: current_user,
          target: tag,
          action_type: :tag_created,
          public_note: moderation_params[:public_note],
          internal_note: moderation_params[:internal_note],
          metadata: {}
        )
      end

      redirect_to mod_tags_path(anchor: "tag-#{tag.id}"), notice: t("moderation.notices.tag_created")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to mod_tags_path, alert: error.record.errors.full_messages.to_sentence
    end

    def update
      ActiveRecord::Base.transaction do
        action_type =
          case params[:tag_action].to_s
          when "rename"
            @tag.update!(tag_params)
            :tag_renamed
          when "archive"
            @tag.update!(state: :archived)
            :tag_archived
          else
            raise ActiveRecord::RecordInvalid, invalid_record(@tag)
          end

        ModeratorAction.create!(
          moderator: current_user,
          target: @tag,
          action_type: action_type,
          public_note: moderation_params[:public_note],
          internal_note: moderation_params[:internal_note],
          metadata: {}
        )
      end

      redirect_to mod_tags_path(anchor: "tag-#{@tag.id}"), notice: t("moderation.notices.tag_updated")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to mod_tags_path(anchor: "tag-#{@tag.id}"), alert: error.record.errors.full_messages.to_sentence
    end

    def merge
      source = Tag.find(params[:source_tag_id])
      target = Tag.find(params[:target_tag_id])

      ActiveRecord::Base.transaction do
        raise ActiveRecord::RecordInvalid, invalid_record(source) if source == target

        source.post_tags.includes(:post).find_each do |post_tag|
          if PostTag.exists?(post: post_tag.post, tag: target)
            post_tag.destroy!
          else
            post_tag.update!(tag: target)
          end
        end

        source.update!(state: :archived)
        ModeratorAction.create!(
          moderator: current_user,
          target: source,
          action_type: :tag_merged,
          public_note: moderation_params[:public_note],
          internal_note: moderation_params[:internal_note],
          metadata: {
            merged_into_id: target.id,
            merged_into_name: target.name
          }
        )
      end

      redirect_to mod_tags_path(anchor: "tag-#{target.id}"), notice: t("moderation.notices.tag_merged")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to mod_tags_path, alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_tag
      @tag = Tag.find(params[:id])
    end

    def tag_params
      params.fetch(:tag, {}).permit(:name)
    end

    def moderation_params
      params.require(:moderation).permit(:public_note, :internal_note)
    end

    def invalid_record(record)
      record.errors.add(:base, :invalid)
      record
    end
  end
end
