require "test_helper"

class ReportTest < ActiveSupport::TestCase
  test "fixture reports are valid" do
    assert reports(:open_post_report).valid?
    assert reports(:resolved_comment_report).valid?
  end

  test "open report requires no resolved fields" do
    report = Report.new(
      reporter: users(:active_member),
      target: posts(:discussion_post),
      reason_code: :spam,
      status: :open
    )
    assert report.valid?
  end

  test "resolved report requires resolved_by and resolved_at" do
    report = Report.new(
      reporter: users(:active_member),
      target: posts(:discussion_post),
      reason_code: :spam,
      status: :resolved
    )
    assert_not report.valid?
    assert_includes report.errors[:resolved_by_id], I18n.t("activerecord.errors.models.report.attributes.resolved_by_id.blank")
    assert_includes report.errors[:resolved_at], I18n.t("activerecord.errors.models.report.attributes.resolved_at.blank")
  end

  test "dismissed report requires resolved_by and resolved_at" do
    report = Report.new(
      reporter: users(:active_member),
      target: posts(:discussion_post),
      reason_code: :spam,
      status: :dismissed
    )
    assert_not report.valid?
    assert_includes report.errors[:resolved_by_id], I18n.t("activerecord.errors.models.report.attributes.resolved_by_id.blank")
    assert_includes report.errors[:resolved_at], I18n.t("activerecord.errors.models.report.attributes.resolved_at.blank")
  end

  test "duplicate open reports by same user on same target are not allowed" do
    existing = reports(:open_post_report)
    report = Report.new(
      reporter: existing.reporter,
      target: existing.target,
      reason_code: :hype,
      status: :open
    )
    assert_not report.valid?
    assert_includes report.errors[:reporter_id], I18n.t("errors.messages.taken")
  end

  test "resolved report does not block new open report" do
    existing = reports(:resolved_comment_report)
    report = Report.new(
      reporter: existing.reporter,
      target: existing.target,
      reason_code: :spam,
      status: :open
    )
    assert report.valid?
  end

  test "creating open report increments target report_count" do
    post = posts(:discussion_post)
    original = post.report_count
    Report.create!(reporter: users(:active_member), target: post, reason_code: :spam, status: :open)
    assert_equal original + 1, post.reload.report_count
  end

  test "resolving open report decrements target report_count" do
    report = reports(:open_post_report)
    post = report.target
    original = post.report_count
    report.update!(status: :resolved, resolved_by: users(:moderator), resolved_at: Time.current)
    assert_equal original - 1, post.reload.report_count
  end

  test "destroying open report decrements target report_count" do
    report = reports(:open_post_report)
    post = report.target
    original = post.report_count
    report.destroy!
    assert_equal original - 1, post.reload.report_count
  end

  test "details is optional" do
    report = Report.new(
      reporter: users(:active_member),
      target: posts(:discussion_post),
      reason_code: :spam,
      status: :open
    )
    assert report.valid?
  end

  test "invalid target type is rejected" do
    report = reports(:open_post_report)
    report.target_type = "Tag"

    assert_not report.valid?
    assert_includes report.errors[:target_type], I18n.t("activerecord.errors.models.report.attributes.target_type.inclusion")
  end

  test "user is a valid report target" do
    report = Report.new(
      reporter: users(:another_active),
      target: users(:active_member),
      reason_code: :spam,
      status: :open
    )

    assert report.valid?
  end

  test "resolved report requires a moderator or admin resolver" do
    report = Report.new(
      reporter: users(:another_active),
      target: posts(:discussion_post),
      reason_code: :spam,
      status: :resolved,
      resolved_by: users(:active_member),
      resolved_at: Time.current
    )

    assert_not report.valid?
    assert_includes report.errors[:resolved_by], I18n.t("activerecord.errors.models.report.attributes.resolved_by.invalid_role")
  end

  test "reopening a report refreshes target report_count" do
    report = reports(:resolved_comment_report)
    comment = report.target
    original = comment.report_count

    report.update!(status: :open, resolved_by: nil, resolved_at: nil)

    assert_equal original + 1, comment.reload.report_count
  end

  test "reopening a report clears resolver metadata" do
    report = reports(:resolved_comment_report)

    report.update!(status: :open)

    assert_nil report.resolved_by
    assert_nil report.resolved_at
  end
end
