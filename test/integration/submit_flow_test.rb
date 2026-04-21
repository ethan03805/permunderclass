require "test_helper"

class SubmitFlowTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:active_member))
  end

  test "GET /submit renders the type picker" do
    get submit_path

    assert_response :success
    assert_select "h1", I18n.t("posts.picker.title")
    assert_select ".type-picker__item", count: Post.post_types.size
  end

  test "GET /submit with a type renders the form, preview, and style guide" do
    get submit_path, params: { post_type: "discussion" }

    assert_response :success
    assert_select "form[data-controller='post-form']"
    assert_select ".preview-shell", 1
    assert_select ".style-guide", 1
    assert_select ".linter-panel", 1
  end

  test "POST /submit creates a discussion post and stores linter flags without blocking publish" do
    assert_difference("Post.count", 1) do
      post submit_path, params: {
        post: {
          post_type: "discussion",
          title: "REVOLUTIONIZE your workflow!!",
          body: "Act now before you miss it.",
          tag_ids: [ tags(:active_tag).id ]
        }
      }
    end

    post_record = Post.where(title: "REVOLUTIONIZE your workflow!!").order(:id).last!

    assert_redirected_to post_path(post_record)
    assert_includes post_record.linter_flags, "revolutionize"
    assert_includes post_record.linter_flags, "multiple_exclamation_marks"
    assert_includes post_record.linter_flags, "exaggerated_urgency"
  end

  test "POST /submit creates a shipped post with an image" do
    assert_difference("Post.count", 1) do
      post submit_path, params: {
        post: {
          post_type: "shipped",
          title: "Released today",
          body: "A plain description.",
          link_url: "https://example.com/product",
          image: uploaded_png,
          tag_ids: [ tags(:active_tag).id ]
        }
      }
    end

    post_record = Post.where(title: "Released today").order(:id).last!
    assert post_record.image.attached?
    assert_redirected_to post_path(post_record)
  end

  test "POST /submit creates a build post with a short video" do
    assert_difference("Post.count", 1) do
      post submit_path, params: {
        post: {
          post_type: "build",
          title: "Current build",
          body: "A plain progress update.",
          build_status: "sharing",
          video: uploaded_mp4(filename: "submit-build.mp4", duration: 1, codec: "libx264")
        }
      }
    end

    post_record = Post.where(title: "Current build").order(:id).last!
    assert post_record.video.attached?
    assert_redirected_to post_path(post_record)
  end
end
