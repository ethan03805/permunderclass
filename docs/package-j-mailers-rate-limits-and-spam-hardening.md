# Package J: Mailers, Rate Limits, and Spam Hardening

## What Changed

Package J adds the remaining reply-notification and hardening work required after Packages C, F, G, and I.

Reply alerts now send email for:

- direct replies to a user's comment
- new comments on a user's post when the commenter is not the post author

Users can now toggle the single `reply_alerts_enabled` preference from their own profile page.

Spam and abuse hardening now includes:

- `Rack::Attack` throttles for sign-up, failed sign-in attempts, post creation, comment creation, and vote mutations
- fresh-account throttles for the first 24 hours after email verification
- honeypot and minimum-submit-time checks on sign-up and post submission
- a disposable email domain blocklist during sign-up
- anonymous cache headers on feed and post HTML responses

The package also tightened the test environment so request throttles and queued mail delivery can be exercised reliably, and made the video-validation tests skip cleanly when `ffprobe` is unavailable locally.

## Files Added Or Modified

- `Gemfile`
- `app/controllers/application_controller.rb`
- `app/controllers/home_controller.rb`
- `app/controllers/posts_controller.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/tags_controller.rb`
- `app/controllers/users_controller.rb`
- `app/jobs/reply_alert_job.rb`
- `app/mailers/reply_alert_mailer.rb`
- `app/models/comment.rb`
- `app/models/post.rb`
- `app/models/user.rb`
- `app/services/disposable_email_blocklist.rb`
- `app/services/login_failure_tracker.rb`
- `app/services/spam_check.rb`
- `app/views/posts/_form.html.erb`
- `app/views/reply_alert_mailer/comment_reply.html.erb`
- `app/views/reply_alert_mailer/comment_reply.text.erb`
- `app/views/reply_alert_mailer/post_comment.html.erb`
- `app/views/reply_alert_mailer/post_comment.text.erb`
- `app/views/shared/_spam_protection_fields.html.erb`
- `app/views/users/new.html.erb`
- `app/views/users/show.html.erb`
- `app/assets/stylesheets/application.css`
- `config/disposable_email_domains.txt`
- `config/environments/test.rb`
- `config/initializers/rack_attack.rb`
- `config/locales/en.yml`
- `config/routes.rb`
- `test/integration/cache_headers_test.rb`
- `test/integration/comments_and_votes_test.rb`
- `test/integration/profile_pages_test.rb`
- `test/integration/rate_limiting_test.rb`
- `test/integration/sign_up_flow_test.rb`
- `test/integration/submit_flow_test.rb`
- `test/mailers/reply_alert_mailer_test.rb`
- `test/models/post_test.rb`
- `test/test_helper.rb`

## Verification

Verified with:

- `bin/test` with `DATABASE_URL=postgresql://postgres:postgres@localhost:5432/permanent_underclass_development`, `TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5432/permanent_underclass_test`, and `PARALLEL_WORKERS=1`
- `bin/lint` with the same database environment variables
- `bin/security` with the same database environment variables

Observed verification results:

- `bin/test` passed with `241` runs, `837` assertions, `0` failures, `0` errors, and `4` skips
- the four skips are video-validation tests that now skip when `ffprobe` is not installed locally
- `bin/lint` passed with no offenses
- `bin/security` passed with no Brakeman warnings and no bundled gem vulnerabilities

## Follow-Up Work Or Known Limitations

- On this machine, the default parallel test boot path can crash inside the local `pg` adapter before assertions run; using `PARALLEL_WORKERS=1` keeps the suite stable.
- Video validation still depends on local `ffprobe` availability for the H.264 and duration checks, so those tests are skipped when that binary is absent.
