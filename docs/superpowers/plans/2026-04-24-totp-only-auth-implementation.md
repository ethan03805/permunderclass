# Passwordless TOTP Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace password-based authentication with TOTP-only authenticator-app sign-in, implementing the spec at `docs/superpowers/specs/2026-04-24-totp-only-auth-design.md`.

**Architecture:** Big-bang replacement (site is pre-launch, no user migration). Rails 8 native encryption for TOTP secrets; `rotp` for RFC 6238 validation; `rqrcode` for server-rendered QR SVGs. One enrollment controller (`EnrollmentsController`) handles both first-time sign-up enrollment and lost-device recovery via a shared page and code path. Rails signed-cookie sessions extended with a `sessions_generation` column so recovery invalidates stale sessions on other devices.

**Tech Stack:** Ruby 3.3, Rails 8.1, PostgreSQL 16, Hotwire (Turbo + Stimulus), `rotp` ~6.3, `rqrcode` ~2.2, Rails Active Record Encryption.

**Notes for all tasks:**
- Preferred wrappers: `bin/test`, `bin/lint`, `bin/security`, `bin/dev`. Use these instead of invoking `bundle exec rails` directly.
- Commit after every task using the git message style of the repo (short, factual, sentence case).
- The overall suite will be **red between tasks** — this is expected during a big-bang rewrite. Each task restores green for its own surface. The suite returns to fully green at Task 17 + Task 20.
- **UI style note (post UI-refactor merge from main):** auth pages use an eyebrow-only heading pattern. No `<h1>`, no `<p class="lede">` intro paragraph. Every new or replaced auth view in this plan follows the shape:
  ```erb
  <section class="auth-shell" aria-labelledby="X-title">
    <p id="X-title" class="eyebrow"><%= t("auth.<section>.eyebrow") %></p>
    <div class="form-shell"> ... </div>
  </section>
  ```
  The `title:` locale key is retained for the `<title>` HTML tag via `content_for :title`. The `intro:` locale key is not used. If you see an existing view in the repo with an `<h1>`, follow the new pattern in the replacement.

---

## Task 1: Prerequisites — Active Record encryption keys (Stop-and-Ask)

**Context:** Rails 8 Active Record encryption needs three keys configured before the `encrypts :totp_secret` declarations added in Task 4 will work. Without them, every User read/write fails. This step cannot be automated by an agent per CLAUDE.md `Stop And Ask` — the user must run it.

**Files:**
- Modify: `config/credentials.yml.enc` (via `bin/rails credentials:edit`)

- [ ] **Step 1: Generate encryption keys locally**

Run: `bin/rails db:encryption:init`

Expected output (three 64-char random values shown under a `active_record_encryption:` block):
```yaml
active_record_encryption:
  primary_key: <64 random chars>
  deterministic_key: <64 random chars>
  key_derivation_salt: <64 random chars>
```

- [ ] **Step 2: Add keys to encrypted credentials**

Run: `bin/rails credentials:edit`

In the editor, paste the YAML block from Step 1 at the top level of the file. Save and close. Rails re-encrypts on save.

- [ ] **Step 3: Verify the keys load**

Run: `bin/rails runner "puts Rails.application.credentials.dig(:active_record_encryption, :primary_key).present?"`

Expected: `true`

- [ ] **Step 4: Commit the credentials file**

```bash
git add config/credentials.yml.enc
git commit -m "Configure Active Record encryption keys for TOTP"
```

---

## Task 2: Foundation — gems and migration

**Files:**
- Modify: `Gemfile`, `Gemfile.lock`
- Create: `db/migrate/<timestamp>_replace_password_with_totp.rb`
- Modify: `db/schema.rb` (regenerated)

- [ ] **Step 1: Update Gemfile**

Edit `Gemfile`. Replace this line:
```ruby
gem "bcrypt", "~> 3.1.7"
```
with:
```ruby
gem "rotp", "~> 6.3"
gem "rqrcode", "~> 2.2"
```

- [ ] **Step 2: Install**

Run: `bundle install`

Expected: `rotp` and `rqrcode` added; `bcrypt` removed.

- [ ] **Step 3: Generate migration skeleton**

Run: `bin/rails generate migration ReplacePasswordWithTotp`

- [ ] **Step 4: Write migration body**

Replace the generated file contents with:
```ruby
class ReplacePasswordWithTotp < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :password_digest, :string, null: false

    add_column :users, :totp_secret, :text
    add_column :users, :totp_candidate_secret, :text
    add_column :users, :totp_candidate_secret_expires_at, :datetime
    add_column :users, :totp_last_used_counter, :bigint
    add_column :users, :sessions_generation, :integer, default: 0, null: false
    add_column :users, :enrollment_token_generation, :integer, default: 0, null: false
  end
end
```

- [ ] **Step 5: Apply migration (dev and test)**

Run: `bin/rails db:migrate`
Run: `RAILS_ENV=test bin/rails db:migrate`

Expected: `db/schema.rb` updated; `password_digest` removed, new columns present.

- [ ] **Step 6: Commit**

```bash
git add Gemfile Gemfile.lock db/migrate db/schema.rb
git commit -m "Swap bcrypt for rotp/rqrcode; add TOTP columns, drop password_digest"
```

---

## Task 3: Routes — remove password + email-verification, add recover + enroll

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Update routes**

In `config/routes.rb`, find and remove these blocks:
```ruby
get "password-reset", to: "password_resets#new", as: :password_reset
post "password-reset", to: "password_resets#create"
get "password-reset/:token", to: "password_resets#edit", as: :password_reset_token
patch "password-reset/:token", to: "password_resets#update"

get "email-verification/:token", to: "email_verifications#show", as: :email_verification
```

Replace with:
```ruby
get "recover", to: "recoveries#new", as: :recover
post "recover", to: "recoveries#create"

get "enroll/:token", to: "enrollments#show", as: :enroll
post "enroll/:token", to: "enrollments#confirm", as: :enroll_confirm
```

- [ ] **Step 2: Verify routes load**

Run: `bin/rails routes | grep -E "(recover|enroll|sign-in|sign-up)"`

Expected: see `recover`, `enroll`, `enroll_confirm`, `sign_in`, `sign_up` routes. `password_reset` and `email_verification` NOT present.

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "Replace password-reset + email-verification routes with recover + enroll"
```

---

## Task 4: User model — password removal, state rename, encryption declarations

**Files:**
- Modify: `app/models/user.rb`
- Modify: `test/fixtures/users.yml`

**Goal:** Get the User model loadable under the new schema (no password_digest), with state rename and encrypted TOTP columns declared. Defer TOTP method implementations to Task 5.

- [ ] **Step 1: Rewrite `app/models/user.rb`**

Replace file contents with:
```ruby
class User < ApplicationRecord
  FRESH_ACCOUNT_WINDOW = 24.hours
  PSEUDONYM_FORMAT = /\A[a-z0-9_]+\z/i

  has_many :posts, dependent: :restrict_with_error
  has_many :comments, dependent: :restrict_with_error
  has_many :reports, as: :target, dependent: :restrict_with_error
  has_many :post_votes, dependent: :destroy
  has_many :comment_votes, dependent: :destroy
  has_many :reports_as_reporter, class_name: "Report", foreign_key: :reporter_id, dependent: :restrict_with_error
  has_many :reports_resolved, class_name: "Report", foreign_key: :resolved_by_id, dependent: :restrict_with_error
  has_many :moderator_actions, foreign_key: :moderator_id, dependent: :restrict_with_error
  has_many :targeted_moderator_actions, as: :target, class_name: "ModeratorAction", dependent: :restrict_with_error

  encrypts :totp_secret
  encrypts :totp_candidate_secret

  enum :role, { member: 0, moderator: 1, admin: 2 }, default: :member, validate: true
  enum :state, {
    pending_enrollment: 0,
    active: 1,
    suspended: 2,
    banned: 3
  }, default: :pending_enrollment, validate: true

  before_validation :normalize_identifiers

  validates :email,
    presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }
  validates :pseudonym,
    presence: true,
    format: { with: PSEUDONYM_FORMAT },
    length: { minimum: 3, maximum: 30 },
    uniqueness: { case_sensitive: false }
  validates :reply_alerts_enabled, inclusion: { in: [ true, false ] }
  validate :email_domain_must_not_be_disposable

  def email_verified?
    email_verified_at.present?
  end

  def fresh_account?(reference_time: Time.current)
    active? && email_verified? && email_verified_at >= (reference_time - FRESH_ACCOUNT_WINDOW)
  end

  def verify_email!
    return if email_verified? || suspended? || banned?

    update!(email_verified_at: Time.current, state: :active)
  end

  private

  def normalize_identifiers
    self.email = email.to_s.strip.downcase.presence
    self.pseudonym = pseudonym.to_s.strip.downcase.presence
  end

  def email_domain_must_not_be_disposable
    return if email.blank? || !DisposableEmailBlocklist.include?(email)

    errors.add(:email, :disposable)
  end
end
```

Removed relative to the old file: `has_secure_password`, `validates :password`, `changing_password?`, `generates_token_for :email_verification`, `generates_token_for :password_reset`, `password_reset_permitted?`.

- [ ] **Step 2: Update `test/fixtures/users.yml`**

Replace file contents with:
```yaml
pending_member:
  pseudonym: pending_builder
  email: pending@example.com
  role: member
  state: pending_enrollment
  email_verified_at:
  reply_alerts_enabled: true

active_member:
  pseudonym: active_builder
  email: active@example.com
  role: member
  state: active
  email_verified_at: <%= 2.days.ago %>
  reply_alerts_enabled: true

suspended_member:
  pseudonym: suspended_builder
  email: suspended@example.com
  role: member
  state: suspended
  email_verified_at: <%= 3.days.ago %>
  reply_alerts_enabled: true

banned_member:
  pseudonym: banned_builder
  email: banned@example.com
  role: member
  state: banned
  email_verified_at: <%= 4.days.ago %>
  reply_alerts_enabled: false

moderator:
  pseudonym: mod_builder
  email: mod@example.com
  role: moderator
  state: active
  email_verified_at: <%= 5.days.ago %>
  reply_alerts_enabled: true

another_active:
  pseudonym: another_builder
  email: another@example.com
  role: member
  state: active
  email_verified_at: <%= 1.day.ago %>
  reply_alerts_enabled: true

admin:
  pseudonym: admin_builder
  email: admin@example.com
  role: admin
  state: active
  email_verified_at: <%= 6.days.ago %>
  reply_alerts_enabled: true
```

(Removed `password_digest` lines and renamed `pending_email_verification` → `pending_enrollment`. Fixtures leave `totp_secret` unset; tests enroll users programmatically when needed via the helper added in Task 5.)

- [ ] **Step 3: Sanity-check the model loads**

Run: `bin/rails runner "User.new(pseudonym: 'sanity', email: 'sanity@example.com').valid?; puts 'OK'"`

Expected: `OK` printed (the new record may not be valid, but the model must load without error).

- [ ] **Step 4: Commit**

```bash
git add app/models/user.rb test/fixtures/users.yml
git commit -m "Remove password from User model; rename state to pending_enrollment; declare encrypted TOTP attributes"
```

---

## Task 5: User model — TOTP methods (TDD)

**Files:**
- Modify: `app/models/user.rb`
- Modify: `test/models/user_test.rb`
- Modify: `test/test_helper.rb`

**Goal:** TDD the TOTP instance methods and the enrollment token on the User model.

- [ ] **Step 1: Add TOTP test helpers to `test/test_helper.rb`**

Replace the `AuthenticationTestHelper` module in `test/test_helper.rb` with:
```ruby
module AuthenticationTestHelper
  # Note: the replay-prevention counter means reusing sign_in_as for the
  # same user within the same 30-second TOTP window will fail the second
  # time. Tests that sign in multiple times per user must travel 31+
  # seconds between calls or use different users.
  def sign_in_as(user)
    enroll_if_needed(user)
    post sign_in_path, params: {
      session: { email: user.email, code: valid_totp_code_for(user) }
    }
  end

  def enroll_if_needed(user)
    return if user.totp_secret.present?

    user.update!(totp_secret: ROTP::Base32.random, email_verified_at: Time.current)
    user.update!(state: :active) if user.pending_enrollment?
  end

  def valid_totp_code_for(user)
    ROTP::TOTP.new(user.totp_secret).now
  end

  def with_env(overrides)
    original = overrides.to_h { |key, _value| [ key, ENV[key] ] }

    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each do |key, value|
      ENV[key] = value
    end
  end

  def spam_check_params(context, started_at: 10.seconds.ago, honeypot: "")
    {
      spam_check: {
        website: honeypot,
        form_started_token: SpamCheck.form_token_for(context, now: started_at)
      }
    }
  end

  def with_stubbed_turnstile_verification(result)
    singleton_class = TurnstileVerification.singleton_class

    singleton_class.alias_method :__original_new_for_test, :new
    singleton_class.define_method(:new) do |*_args, **_kwargs|
      Struct.new(:verified?).new(result)
    end

    yield
  ensure
    singleton_class.alias_method :new, :__original_new_for_test
    singleton_class.remove_method :__original_new_for_test
  end
end
```

- [ ] **Step 2: Write failing tests for `verify_totp`**

In `test/models/user_test.rb`, add (or replace equivalent block) inside the main test class:
```ruby
test "verify_totp accepts a valid current code" do
  user = users(:active_member)
  enroll_if_needed(user)

  assert user.verify_totp(valid_totp_code_for(user))
end

test "verify_totp rejects an invalid code" do
  user = users(:active_member)
  enroll_if_needed(user)

  refute user.verify_totp("000000")
end

test "verify_totp rejects a replayed code within the same window" do
  user = users(:active_member)
  enroll_if_needed(user)
  code = valid_totp_code_for(user)

  assert user.verify_totp(code)
  refute user.verify_totp(code), "same code must not be accepted twice"
end

test "verify_totp returns false when no secret is set" do
  user = users(:pending_member)

  refute user.verify_totp("123456")
end
```

- [ ] **Step 3: Run tests — expect red**

Run: `bin/test test/models/user_test.rb`

Expected: the four new tests fail (`NoMethodError: undefined method 'verify_totp'`).

- [ ] **Step 4: Implement `verify_totp` on User**

In `app/models/user.rb`, inside the `User` class (above `private`), add:
```ruby
def totp
  return if totp_secret.blank?

  @totp ||= ROTP::TOTP.new(totp_secret, issuer: Rails.configuration.x.totp_issuer || "permanentunderclass.me")
end

def verify_totp(code)
  return false if totp.nil? || code.blank?

  counter = totp.verify(code.to_s, drift_behind: 30, drift_ahead: 30, after: totp_last_used_counter)
  return false if counter.nil?

  update_column(:totp_last_used_counter, counter)
  true
end
```

And in `config/application.rb`, inside the `Application` class body, add:
```ruby
config.x.totp_issuer = "permanentunderclass.me"
```

- [ ] **Step 5: Run tests — expect green**

Run: `bin/test test/models/user_test.rb`

Expected: the four new tests pass.

- [ ] **Step 6: Write failing tests for `begin_enrollment!` / `complete_enrollment!`**

Append to `test/models/user_test.rb`:
```ruby
test "begin_enrollment! generates a candidate secret and expiry" do
  user = users(:pending_member)
  assert_nil user.totp_candidate_secret

  user.begin_enrollment!

  assert user.reload.totp_candidate_secret.present?
  assert user.totp_candidate_secret_expires_at > 25.minutes.from_now
end

test "begin_enrollment! is idempotent while the candidate is unexpired" do
  user = users(:pending_member)
  user.begin_enrollment!
  first_secret = user.reload.totp_candidate_secret

  user.begin_enrollment!

  assert_equal first_secret, user.reload.totp_candidate_secret
end

test "begin_enrollment! regenerates the candidate after expiry" do
  user = users(:pending_member)
  user.begin_enrollment!
  first_secret = user.reload.totp_candidate_secret

  travel 31.minutes do
    user.begin_enrollment!
  end

  refute_equal first_secret, user.reload.totp_candidate_secret
end

test "begin_enrollment! does not modify totp_secret during recovery" do
  user = users(:active_member)
  enroll_if_needed(user)
  existing = user.totp_secret

  user.begin_enrollment!

  assert_equal existing, user.reload.totp_secret
  assert user.totp_candidate_secret.present?
  refute_equal existing, user.totp_candidate_secret
end

test "complete_enrollment! promotes candidate to in-use and clears candidate" do
  user = users(:pending_member)
  user.begin_enrollment!
  candidate = user.totp_candidate_secret

  user.complete_enrollment!

  user.reload
  assert_equal candidate, user.totp_secret
  assert_nil user.totp_candidate_secret
  assert_nil user.totp_candidate_secret_expires_at
end

test "complete_enrollment! transitions pending_enrollment to active and sets email_verified_at" do
  freeze_time do
    user = users(:pending_member)
    user.begin_enrollment!

    user.complete_enrollment!

    assert user.reload.active?
    assert_equal Time.current, user.email_verified_at
  end
end

test "complete_enrollment! bumps sessions_generation for active users (recovery)" do
  user = users(:active_member)
  enroll_if_needed(user)
  before = user.sessions_generation

  user.begin_enrollment!
  user.complete_enrollment!

  assert_equal before + 1, user.reload.sessions_generation
end

test "complete_enrollment! does NOT change email_verified_at on recovery" do
  user = users(:active_member)
  enroll_if_needed(user)
  original = user.email_verified_at

  user.begin_enrollment!
  user.complete_enrollment!

  assert_in_delta original, user.reload.email_verified_at, 1.second
end
```

- [ ] **Step 7: Run tests — expect red**

Run: `bin/test test/models/user_test.rb`

Expected: the new tests fail with missing methods.

- [ ] **Step 8: Implement `begin_enrollment!` and `complete_enrollment!`**

In `app/models/user.rb`, above `private`, add:
```ruby
ENROLLMENT_CANDIDATE_TTL = 30.minutes

def begin_enrollment!
  now = Time.current
  fresh = totp_candidate_secret.blank? || totp_candidate_secret_expires_at.nil? || totp_candidate_secret_expires_at < now

  return unless fresh

  update!(
    totp_candidate_secret: ROTP::Base32.random,
    totp_candidate_secret_expires_at: now + ENROLLMENT_CANDIDATE_TTL
  )
end

def complete_enrollment!
  raise ActiveRecord::RecordInvalid.new(self), "No candidate secret" if totp_candidate_secret.blank?

  updates = {
    totp_secret: totp_candidate_secret,
    totp_candidate_secret: nil,
    totp_candidate_secret_expires_at: nil,
    totp_last_used_counter: nil
  }

  if pending_enrollment?
    updates[:state] = :active
    updates[:email_verified_at] = Time.current
  else
    updates[:sessions_generation] = sessions_generation + 1
  end

  update!(updates)
end
```

- [ ] **Step 9: Run tests — expect green**

Run: `bin/test test/models/user_test.rb`

Expected: all TOTP and enrollment tests pass.

- [ ] **Step 10: Add enrollment token generator with test**

Append to `test/models/user_test.rb`:
```ruby
test "generates_token_for :enrollment tokens are valid and round-trip" do
  user = users(:pending_member)

  token = user.generate_token_for(:enrollment)

  assert_equal user, User.find_by_token_for(:enrollment, token)
end

test "enrollment token is invalidated when enrollment_token_generation bumps" do
  user = users(:pending_member)
  token = user.generate_token_for(:enrollment)

  user.update!(enrollment_token_generation: user.enrollment_token_generation + 1)

  assert_nil User.find_by_token_for(:enrollment, token)
end

test "enrollment token is invalidated by first enrollment completion" do
  user = users(:pending_member)
  user.begin_enrollment!
  token = user.generate_token_for(:enrollment)

  user.complete_enrollment!

  assert_nil User.find_by_token_for(:enrollment, token)
end
```

- [ ] **Step 11: Run tests — expect red**

Run: `bin/test test/models/user_test.rb`

- [ ] **Step 12: Add the token generator to User model**

In `app/models/user.rb`, above the first method definition (after the validations), add:
```ruby
ENROLLMENT_TOKEN_TTL = 30.minutes

generates_token_for :enrollment, expires_in: ENROLLMENT_TOKEN_TTL do
  [email_verified_at&.to_i || 0, enrollment_token_generation]
end
```

- [ ] **Step 13: Run tests — expect green**

Run: `bin/test test/models/user_test.rb`

- [ ] **Step 14: Run full unit-test layer**

Run: `bin/test test/models test/services test/mailers`

Expected: model tests green; mailer and service tests may still be red (fixed in later tasks).

- [ ] **Step 15: Commit**

```bash
git add app/models/user.rb test/models/user_test.rb test/test_helper.rb config/application.rb
git commit -m "Add TOTP methods and enrollment token to User model"
```

---

## Task 6: UserMailer — enrollment_link (replaces email_verification + password_reset)

**Files:**
- Modify: `app/mailers/user_mailer.rb`
- Create: `app/views/user_mailer/enrollment_link.html.erb`
- Create: `app/views/user_mailer/enrollment_link.text.erb`
- Delete: `app/views/user_mailer/email_verification.html.erb`
- Delete: `app/views/user_mailer/email_verification.text.erb`
- Delete: `app/views/user_mailer/password_reset.html.erb`
- Delete: `app/views/user_mailer/password_reset.text.erb`
- Modify: `test/mailers/user_mailer_test.rb`
- Modify: `config/locales/en.yml` — add `mailers.user_mailer.enrollment_link.*`, keep `password_reset` + `email_verification` keys alive until Task 15 to avoid breaking non-mailer code paths.

- [ ] **Step 1: Replace `app/mailers/user_mailer.rb` contents**

```ruby
class UserMailer < ApplicationMailer
  def enrollment_link(user)
    @user = user
    @enrollment_url = enroll_url(token: user.generate_token_for(:enrollment))

    mail(
      subject: t("mailers.user_mailer.enrollment_link.subject"),
      to: user.email
    )
  end
end
```

- [ ] **Step 2: Create `app/views/user_mailer/enrollment_link.html.erb`**

```erb
<p><%= t("mailers.user_mailer.enrollment_link.greeting", pseudonym: @user.pseudonym) %></p>

<p><%= t("mailers.user_mailer.enrollment_link.body") %></p>

<p><%= link_to t("mailers.user_mailer.enrollment_link.cta"), @enrollment_url %></p>

<p><%= t("mailers.user_mailer.enrollment_link.expiry") %></p>
```

- [ ] **Step 3: Create `app/views/user_mailer/enrollment_link.text.erb`**

```erb
<%= t("mailers.user_mailer.enrollment_link.greeting", pseudonym: @user.pseudonym) %>

<%= t("mailers.user_mailer.enrollment_link.body") %>

<%= @enrollment_url %>

<%= t("mailers.user_mailer.enrollment_link.expiry") %>
```

- [ ] **Step 4: Add mailer locales**

In `config/locales/en.yml`, under the `en:` → `mailers:` → `user_mailer:` branch, add a new key set (keep the existing `email_verification` and `password_reset` entries untouched for now — Task 15 removes them):
```yaml
            enrollment_link:
              subject: "Finish setting up your account"
              greeting: "Hi %{pseudonym},"
              body: "Use the link below to set up your authenticator app. This is how you will sign in from now on."
              cta: "Set up authenticator"
              expiry: "This link expires in 30 minutes. If it expires, request a new one from the sign-in page."
```

- [ ] **Step 5: Delete obsolete mailer templates**

```bash
rm app/views/user_mailer/email_verification.html.erb
rm app/views/user_mailer/email_verification.text.erb
rm app/views/user_mailer/password_reset.html.erb
rm app/views/user_mailer/password_reset.text.erb
```

- [ ] **Step 6: Rewrite `test/mailers/user_mailer_test.rb`**

Replace contents with:
```ruby
require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "enrollment_link delivers a signed link addressed to the user" do
    user = users(:pending_member)

    mail = UserMailer.enrollment_link(user)

    assert_equal [user.email], mail.to
    assert_equal I18n.t("mailers.user_mailer.enrollment_link.subject"), mail.subject
    assert_match %r{http://.+/enroll/[A-Za-z0-9_\-]+}, mail.body.encoded
  end

  test "enrollment_link body references the pseudonym" do
    user = users(:pending_member)

    mail = UserMailer.enrollment_link(user)

    assert_match user.pseudonym, mail.body.encoded
  end
end
```

- [ ] **Step 7: Run mailer tests — expect green**

Run: `bin/test test/mailers/user_mailer_test.rb`

Expected: both tests pass.

- [ ] **Step 8: Commit**

```bash
git add app/mailers/user_mailer.rb app/views/user_mailer/ test/mailers/user_mailer_test.rb config/locales/en.yml
git commit -m "Replace email_verification + password_reset mailers with enrollment_link"
```

---

## Task 7: EnrollmentsController + view + Stimulus countdown

**Files:**
- Create: `app/controllers/enrollments_controller.rb`
- Create: `app/views/enrollments/show.html.erb`
- Create: `app/javascript/controllers/totp_countdown_controller.js`
- Modify: `app/javascript/controllers/index.js` (if present — register the new controller)
- Modify: `app/services/login_failure_tracker.rb` (add per-user keys — Task 12 fully tests this; minimal addition here for use in this controller)
- Modify: `config/locales/en.yml` — add `enrollment.*` keys
- Create: `test/controllers/enrollments_controller_test.rb`

**Note:** Per-user rate limit extension to `LoginFailureTracker` lands here because EnrollmentsController#confirm needs it; the dedicated per-user test coverage is in Task 12.

- [ ] **Step 1: Extend `app/services/login_failure_tracker.rb`**

Replace file contents with:
```ruby
class LoginFailureTracker
  IP_PREFIX = "login-failure:ip".freeze
  USER_PREFIX = "login-failure:user".freeze
  IP_LIMIT = 10
  USER_LIMIT = 5
  WINDOW = 15.minutes

  class << self
    def blocked?(ip_address)
      read(ip_key(ip_address)) >= IP_LIMIT
    end

    def blocked_user?(user_id)
      return false if user_id.blank?

      read(user_key(user_id)) >= USER_LIMIT
    end

    def track(ip_address)
      increment(ip_key(ip_address)) if ip_address.present?
    end

    def track_user(user_id)
      increment(user_key(user_id)) if user_id.present?
    end

    def reset(ip_address)
      Rails.cache.delete(ip_key(ip_address)) if ip_address.present?
    end

    def reset_user(user_id)
      Rails.cache.delete(user_key(user_id)) if user_id.present?
    end

    def count(ip_address)
      read(ip_key(ip_address))
    end

    private

    def ip_key(ip_address)
      "#{IP_PREFIX}:#{ip_address}"
    end

    def user_key(user_id)
      "#{USER_PREFIX}:#{user_id}"
    end

    def read(key)
      Rails.cache.read(key).to_i
    end

    def increment(key)
      new_value = Rails.cache.increment(key, 1, expires_in: WINDOW)
      return new_value if new_value

      current = Rails.cache.read(key).to_i + 1
      Rails.cache.write(key, current, expires_in: WINDOW)
      current
    end
  end
end
```

- [ ] **Step 2: Create `app/controllers/enrollments_controller.rb`**

```ruby
class EnrollmentsController < ApplicationController
  before_action :load_user_from_token

  def show
    if enrollment_allowed?
      @user.begin_enrollment!
      @qr_svg = render_qr_svg(@user.totp_candidate_secret)
    end
  end

  def confirm
    return unless enrollment_allowed?

    ip = request.remote_ip
    if LoginFailureTracker.blocked?(ip) || LoginFailureTracker.blocked_user?(@user.id)
      redirect_to enroll_path(token: params[:token]), alert: t("auth.enrollment.rate_limited")
      return
    end

    candidate = @user.totp_candidate_secret
    code = params.dig(:enrollment, :code).to_s

    if candidate.present? && verify_candidate(candidate, code)
      @user.complete_enrollment!
      LoginFailureTracker.reset(ip)
      LoginFailureTracker.reset_user(@user.id)
      start_session_for(@user)
      redirect_to root_path, notice: t("auth.enrollment.success")
    else
      LoginFailureTracker.track(ip)
      LoginFailureTracker.track_user(@user.id)
      @qr_svg = render_qr_svg(candidate)
      flash.now[:alert] = t("auth.enrollment.invalid_code")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_user_from_token
    @user = User.find_by_token_for(:enrollment, params[:token])

    if @user.nil?
      redirect_to sign_in_path, alert: t("auth.enrollment.invalid_token")
      return
    end

    if @user.suspended? || @user.banned?
      redirect_to root_path, alert: blocked_user_message(@user)
    end
  end

  def enrollment_allowed?
    @user.present? && !@user.suspended? && !@user.banned?
  end

  def verify_candidate(candidate, code)
    return false if code.blank?

    ROTP::TOTP.new(candidate).verify(code, drift_behind: 30, drift_ahead: 30).present?
  end

  def render_qr_svg(secret)
    totp = ROTP::TOTP.new(secret, issuer: Rails.configuration.x.totp_issuer)
    uri = totp.provisioning_uri(@user.email)
    RQRCode::QRCode.new(uri).as_svg(standalone: true, module_size: 4, use_path: true)
  end
end
```

- [ ] **Step 3: Create `app/views/enrollments/show.html.erb`**

```erb
<% content_for :title, page_title(t("auth.enrollment.title")) %>

<section class="auth-shell" aria-labelledby="enrollment-title">
  <p id="enrollment-title" class="eyebrow"><%= t("auth.enrollment.eyebrow") %></p>

  <div class="form-shell">
    <% if @qr_svg %>
      <figure class="totp-qr" aria-label="<%= t("auth.enrollment.qr_alt") %>">
        <%= raw @qr_svg %>
      </figure>

      <p class="supporting-copy"><%= t("auth.enrollment.instructions") %></p>

      <%= form_with scope: :enrollment, url: enroll_confirm_path(token: params[:token]), class: "form-stack" do |form| %>
        <div class="field-group">
          <%= form.label :code, t("auth.fields.code") %>
          <%= form.text_field :code, inputmode: "numeric", autocomplete: "one-time-code", pattern: "[0-9]*", maxlength: 6, required: true %>
          <p class="field-hint" data-controller="totp-countdown" data-totp-countdown-template-value="<%= t("auth.totp.countdown_html") %>">
            <%= t("auth.totp.countdown_fallback") %>
          </p>
        </div>

        <div class="actions-row">
          <%= form.submit t("auth.enrollment.submit"), class: "button" %>
        </div>
      <% end %>
    <% end %>
  </div>
</section>
```

- [ ] **Step 4: Create `app/javascript/controllers/totp_countdown_controller.js`**

```javascript
import { Controller } from "@hotwired/stimulus"

// Displays seconds remaining until the next 30-second TOTP window boundary.
// Uses wall-clock math independent of any per-user state — safe to render
// unconditionally on any page that accepts a TOTP code.
export default class extends Controller {
  static values = { template: String }

  connect() {
    this.render()
    this.interval = setInterval(() => this.render(), 1000)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  }

  render() {
    const seconds = 30 - (Math.floor(Date.now() / 1000) % 30)
    const template = this.templateValue || "Code rotates in {seconds}s"
    this.element.innerHTML = template.replace("{seconds}", `<strong>${seconds}s</strong>`)
  }
}
```

- [ ] **Step 5: Register the Stimulus controller**

If `app/javascript/controllers/index.js` exists, confirm it uses `eagerLoadControllersFrom` or similar auto-registration (Rails default). If it needs an explicit import, add:
```javascript
import TotpCountdownController from "./totp_countdown_controller"
application.register("totp-countdown", TotpCountdownController)
```

Otherwise, the Rails importmap + stimulus-loading conventions auto-discover `*_controller.js` files — no explicit registration needed.

- [ ] **Step 6: Add locale keys**

In `config/locales/en.yml`, under `en:` → `auth:`, add:
```yaml
      enrollment:
        eyebrow: "Set up your authenticator"
        title: "Set up your authenticator"
        qr_alt: "QR code containing your authenticator setup URI"
        instructions: "Scan the QR with any authenticator app (Duo, Google Authenticator, Authy, 1Password, etc.), then enter the 6-digit code it shows. If your app can't scan a QR code, copy the secret shown under the image into the app manually."
        submit: "Finish setting up"
        success: "You're set up. Welcome."
        invalid_token: "That link is invalid or has expired. Request a new one."
        invalid_code: "That code did not match. Try again with the current code from your authenticator."
        rate_limited: "Too many attempts. Try again in a few minutes."
      totp:
        countdown_html: "Your code rotates in {seconds}."
        countdown_fallback: "Your code rotates every 30 seconds."
```

Also, under `en:` → `auth:` → `fields:` (if not already present), add:
```yaml
        code: "Code"
```

(Keep the existing `auth.fields.email` and related entries unchanged.)

- [ ] **Step 7: Write controller tests**

Create `test/controllers/enrollments_controller_test.rb`:
```ruby
require "test_helper"

class EnrollmentsControllerTest < ActionDispatch::IntegrationTest
  test "GET /enroll/:token for a pending user generates a candidate and renders the QR" do
    user = users(:pending_member)
    token = user.generate_token_for(:enrollment)

    get enroll_path(token: token)

    assert_response :success
    assert_match %r{<svg}, response.body
    assert user.reload.totp_candidate_secret.present?
  end

  test "GET /enroll/:token with a tampered token redirects to sign-in" do
    get enroll_path(token: "bogus-token")

    assert_redirected_to sign_in_path
  end

  test "GET /enroll/:token for a suspended user redirects to root" do
    user = users(:suspended_member)
    token = user.generate_token_for(:enrollment)

    get enroll_path(token: token)

    assert_redirected_to root_path
  end

  test "POST /enroll/:token with a valid code activates the pending user and signs them in" do
    user = users(:pending_member)
    user.begin_enrollment!
    token = user.generate_token_for(:enrollment)
    code = ROTP::TOTP.new(user.totp_candidate_secret).now

    post enroll_confirm_path(token: token), params: { enrollment: { code: code } }

    assert_redirected_to root_path
    user.reload
    assert user.active?
    assert user.totp_secret.present?
    assert_nil user.totp_candidate_secret
  end

  test "POST /enroll/:token with a wrong code re-renders the QR" do
    user = users(:pending_member)
    user.begin_enrollment!
    token = user.generate_token_for(:enrollment)

    post enroll_confirm_path(token: token), params: { enrollment: { code: "000000" } }

    assert_response :unprocessable_entity
    assert_match %r{<svg}, response.body
    refute user.reload.active?
  end

  test "POST /enroll/:token rotates the candidate on recovery without touching totp_secret until success" do
    user = users(:active_member)
    enroll_if_needed(user)
    original_secret = user.totp_secret

    # Start a recovery session
    get enroll_path(token: user.generate_token_for(:enrollment))

    assert user.reload.totp_candidate_secret.present?
    assert_equal original_secret, user.totp_secret, "in-use secret must not change before completion"
  end
end
```

- [ ] **Step 8: Run controller tests — expect green**

Run: `bin/test test/controllers/enrollments_controller_test.rb`

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/enrollments_controller.rb app/views/enrollments app/javascript/controllers/totp_countdown_controller.js app/services/login_failure_tracker.rb config/locales/en.yml test/controllers/enrollments_controller_test.rb
git commit -m "Add EnrollmentsController with shared enrollment/recovery flow and TOTP countdown"
```

---

## Task 8: RecoveriesController + view

**Files:**
- Create: `app/controllers/recoveries_controller.rb`
- Create: `app/views/recoveries/new.html.erb`
- Modify: `config/locales/en.yml` — add `auth.recovery.*`
- Create: `test/controllers/recoveries_controller_test.rb`

- [ ] **Step 1: Create `app/controllers/recoveries_controller.rb`**

```ruby
class RecoveriesController < ApplicationController
  before_action :require_signed_out_user!

  def new; end

  def create
    unless turnstile_verified?
      redirect_to sign_in_path, notice: t("auth.recovery.submitted")
      return
    end

    email = recovery_params[:email].to_s.strip.downcase
    user = User.find_by(email: email) if email.present?

    if user && !user.suspended? && !user.banned?
      user.update!(enrollment_token_generation: user.enrollment_token_generation + 1)
      UserMailer.enrollment_link(user).deliver_later
    end

    redirect_to sign_in_path, notice: t("auth.recovery.submitted")
  end

  private

  def recovery_params
    params.require(:recovery).permit(:email)
  end
end
```

- [ ] **Step 2: Create `app/views/recoveries/new.html.erb`**

```erb
<% content_for :title, page_title(t("auth.recovery.title")) %>

<% if turnstile_site_key.present? %>
  <% content_for :head do %>
    <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
  <% end %>
<% end %>

<section class="auth-shell" aria-labelledby="recovery-title">
  <p id="recovery-title" class="eyebrow"><%= t("auth.recovery.eyebrow") %></p>

  <div class="form-shell">
    <p class="supporting-copy"><%= t("auth.recovery.helper") %></p>

    <%= form_with scope: :recovery, url: recover_path, class: "form-stack" do |form| %>
      <div class="field-group">
        <%= form.label :email, t("auth.fields.email") %>
        <%= form.email_field :email, autocomplete: "email", required: true %>
      </div>

      <% if turnstile_site_key.present? %>
        <div class="field-group">
          <div class="cf-turnstile" data-sitekey="<%= turnstile_site_key %>"></div>
        </div>
      <% end %>

      <div class="actions-row">
        <%= form.submit t("auth.recovery.submit"), class: "button" %>
      </div>
    <% end %>
  </div>
</section>
```

- [ ] **Step 3: Add recovery locale keys**

Under `en:` → `auth:` in `config/locales/en.yml`, add:
```yaml
      recovery:
        eyebrow: "Recover account access"
        title: "Recover account access"
        helper: "Enter the email you signed up with. If it matches an account, we'll send a link to set up a new authenticator."
        submit: "Send recovery link"
        submitted: "If an account exists, a recovery email has been sent."
```

- [ ] **Step 4: Write controller tests**

Create `test/controllers/recoveries_controller_test.rb`:
```ruby
require "test_helper"

class RecoveriesControllerTest < ActionDispatch::IntegrationTest
  test "POST /recover with a known active email enqueues an enrollment_link email" do
    user = users(:active_member)

    with_stubbed_turnstile_verification(true) do
      assert_enqueued_emails 1 do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    assert_redirected_to sign_in_path
    assert_equal I18n.t("auth.recovery.submitted"), flash[:notice]
  end

  test "POST /recover with an unknown email does not enqueue email but shows same notice" do
    with_stubbed_turnstile_verification(true) do
      assert_no_enqueued_emails do
        post recover_path, params: { recovery: { email: "nobody@example.com" } }
      end
    end

    assert_redirected_to sign_in_path
    assert_equal I18n.t("auth.recovery.submitted"), flash[:notice]
  end

  test "POST /recover with a suspended user does not enqueue email but shows same notice" do
    user = users(:suspended_member)

    with_stubbed_turnstile_verification(true) do
      assert_no_enqueued_emails do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    assert_redirected_to sign_in_path
  end

  test "POST /recover bumps enrollment_token_generation to invalidate prior links" do
    user = users(:active_member)
    before = user.enrollment_token_generation

    with_stubbed_turnstile_verification(true) do
      post recover_path, params: { recovery: { email: user.email } }
    end

    assert_equal before + 1, user.reload.enrollment_token_generation
  end

  test "POST /recover with failed Turnstile does not enqueue email" do
    user = users(:active_member)

    with_stubbed_turnstile_verification(false) do
      assert_no_enqueued_emails do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    assert_redirected_to sign_in_path
  end
end
```

- [ ] **Step 5: Run controller tests — expect green**

Run: `bin/test test/controllers/recoveries_controller_test.rb`

- [ ] **Step 6: Commit**

```bash
git add app/controllers/recoveries_controller.rb app/views/recoveries config/locales/en.yml test/controllers/recoveries_controller_test.rb
git commit -m "Add RecoveriesController with generic response and enrollment-link resend"
```

---

## Task 9: SessionsController rewrite + sign-in view

**Files:**
- Modify: `app/controllers/sessions_controller.rb`
- Modify: `app/views/sessions/new.html.erb`
- Modify: `config/locales/en.yml` — update `auth.sign_in.*` keys

- [ ] **Step 1: Replace `app/controllers/sessions_controller.rb`**

```ruby
class SessionsController < ApplicationController
  before_action :require_authenticated_user!, only: :destroy
  before_action :require_signed_out_user!, only: %i[create new]

  def new; end

  def create
    ip = request.remote_ip

    if LoginFailureTracker.blocked?(ip)
      redirect_to sign_in_path, alert: t("auth.sign_in.invalid_credentials")
      return
    end

    email = session_params[:email].to_s.strip.downcase
    code = session_params[:code].to_s
    user = User.find_by(email: email) if email.present?

    if user&.active? && !LoginFailureTracker.blocked_user?(user.id) && user.verify_totp(code)
      LoginFailureTracker.reset(ip)
      LoginFailureTracker.reset_user(user.id)
      start_session_for(user)
      redirect_to root_path, notice: t("auth.sign_in.success")
      return
    end

    LoginFailureTracker.track(ip)
    LoginFailureTracker.track_user(user.id) if user

    if user&.suspended? || user&.banned?
      redirect_to sign_in_path, alert: blocked_user_message(user)
    else
      redirect_to sign_in_path, alert: t("auth.sign_in.invalid_credentials")
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: t("auth.sign_out.success")
  end

  private

  def session_params
    params.require(:session).permit(:email, :code)
  end
end
```

- [ ] **Step 2: Replace `app/views/sessions/new.html.erb`**

```erb
<% content_for :title, page_title(t("auth.sign_in.title")) %>

<section class="auth-shell" aria-labelledby="sign-in-title">
  <p id="sign-in-title" class="eyebrow"><%= t("auth.sign_in.eyebrow") %></p>

  <div class="form-shell">
    <%= form_with scope: :session, url: sign_in_path, class: "form-stack" do |form| %>
      <div class="field-group">
        <%= form.label :email, t("auth.fields.email") %>
        <%= form.email_field :email, autocomplete: "email", required: true %>
      </div>

      <div class="field-group">
        <%= form.label :code, t("auth.fields.code") %>
        <%= form.text_field :code, inputmode: "numeric", autocomplete: "one-time-code", pattern: "[0-9]*", maxlength: 6, required: true %>
        <p class="field-hint" data-controller="totp-countdown" data-totp-countdown-template-value="<%= t("auth.totp.countdown_html") %>">
          <%= t("auth.totp.countdown_fallback") %>
        </p>
      </div>

      <div class="actions-row">
        <%= form.submit t("auth.sign_in.submit"), class: "button" %>
        <%= link_to t("auth.recovery.link"), recover_path, class: "auxiliary-link" %>
      </div>
    <% end %>

    <p class="supporting-copy"><%= t("auth.sign_in.supporting_copy_html", sign_up_path: sign_up_path) %></p>
  </div>
</section>
```

- [ ] **Step 3: Update sign-in locale keys**

In `config/locales/en.yml`, under `en:` → `auth:` → `sign_in:`, keep the existing `eyebrow: "Sign in"` and `title: "Sign in"` (already updated by the recent UI refactor). Remove any `intro:` key if present. Update other keys to:
```yaml
      sign_in:
        eyebrow: "Sign in"
        title: "Sign in"
        invalid_credentials: "Couldn't sign in. Your current code rotates every 30 seconds — try again with the next one."
        success: "Signed in."
        submit: "Sign in"
        supporting_copy_html: "Don't have an account? <a href=\"%{sign_up_path}\">Create one</a>."
```

Delete any `pending_email_verification` sub-key from the `sign_in` block (it no longer applies — pending users can't sign in).

And extend `auth.recovery` (merged with the block added in Task 8) with:
```yaml
      recovery:
        # ... existing keys added in Task 8 ...
        link: "Can't access your authenticator? Recover access"
```

- [ ] **Step 4: Smoke check — routes + view render**

Run: `bin/rails runner "puts Rails.application.routes.url_helpers.sign_in_path"`
Expected: `/sign-in`

Run: `bin/test test/controllers/enrollments_controller_test.rb test/controllers/recoveries_controller_test.rb`
Expected: still green.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/sessions_controller.rb app/views/sessions/new.html.erb config/locales/en.yml
git commit -m "Rewrite SessionsController for email + TOTP single-form sign-in"
```

---

## Task 10: UsersController simplification + sign-up view

**Files:**
- Modify: `app/controllers/users_controller.rb`
- Modify: `app/views/users/new.html.erb`
- Modify: `config/locales/en.yml` — update `auth.sign_up.*` keys

- [ ] **Step 1: Update `UsersController#create`**

In `app/controllers/users_controller.rb`, change the `create` action and `user_params` method:
```ruby
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
    UserMailer.enrollment_link(@user).deliver_later
    redirect_to sign_in_path, notice: t("auth.sign_up.submitted")
  else
    render :new, status: :unprocessable_entity
  end
end
```

And replace `user_params`:
```ruby
def user_params
  params.require(:user).permit(:email, :pseudonym)
end
```

Note: `start_session_for(@user)` is removed — new accounts are unauthenticated until enrollment completes.

- [ ] **Step 2: Update `app/views/users/new.html.erb`**

Remove the two password field groups (`password` and `password_confirmation`). The resulting form should contain only `pseudonym`, `email`, Turnstile, and the submit button. Preserve the post-refactor eyebrow pattern (no `<h1>`, no intro paragraph):
```erb
<% content_for :title, page_title(t("auth.sign_up.title")) %>

<% if turnstile_site_key.present? %>
  <% content_for :head do %>
    <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
  <% end %>
<% end %>

<section class="auth-shell" aria-labelledby="sign-up-title">
  <p id="sign-up-title" class="eyebrow"><%= t("auth.sign_up.eyebrow") %></p>

  <div class="form-shell">
    <%= render "shared/form_errors", object: @user %>

    <%= form_with model: @user, url: sign_up_path, class: "form-stack" do |form| %>
      <%= render "shared/spam_protection_fields", context: :sign_up %>

      <div class="field-group">
        <%= form.label :pseudonym, t("auth.fields.pseudonym") %>
        <%= form.text_field :pseudonym, autocomplete: "nickname", required: true %>
        <p class="field-hint"><%= t("auth.sign_up.pseudonym_hint") %></p>
      </div>

      <div class="field-group">
        <%= form.label :email, t("auth.fields.email") %>
        <%= form.email_field :email, autocomplete: "email", required: true %>
      </div>

      <% if turnstile_site_key.present? %>
        <div class="field-group">
          <div class="cf-turnstile" data-sitekey="<%= turnstile_site_key %>"></div>
        </div>
      <% end %>

      <div class="actions-row">
        <%= form.submit t("auth.sign_up.submit"), class: "button" %>
      </div>
    <% end %>

    <p class="supporting-copy"><%= t("auth.sign_up.supporting_copy_html", sign_in_path: sign_in_path) %></p>
  </div>
</section>
```

- [ ] **Step 3: Update sign-up locale keys**

In `config/locales/en.yml` under `en:` → `auth:` → `sign_up:`, keep the existing `eyebrow:` and `title:` keys (already set to `"Account"` and `"Create an account"` by the recent UI refactor). Remove any `intro:` key if present. Replace the rest with:
```yaml
      sign_up:
        eyebrow: "Account"
        title: "Create an account"
        submit: "Create account"
        submitted: "Check your email to finish setting up your account."
        pseudonym_hint: "Use 3 to 30 letters, numbers, or underscores."
        supporting_copy_html: "Already have an account? <a href=\"%{sign_in_path}\">Sign in</a>."
```

Remove the old `sign_up.success` message (which implied an auto-session) — it's replaced by `sign_up.submitted`.

Leave the `auth.password_reset.*` subtree and `auth.fields.password*` keys in place for now — Task 15 cleans them up after all code references are gone.

- [ ] **Step 4: Run any existing integration test that touches sign-up or sign-in (expect mostly red, some green)**

Run: `bin/test test/integration/sign_up_flow_test.rb`
Expected: existing tests likely fail because they assert password fields. They are rewritten in Task 17.

Run: `bin/test test/controllers/enrollments_controller_test.rb test/controllers/recoveries_controller_test.rb`
Expected: still green.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/users_controller.rb app/views/users/new.html.erb config/locales/en.yml
git commit -m "Sign-up: collect email + pseudonym only, enqueue enrollment email, no auto-session"
```

---

## Task 11: Authentication concern — sessions_generation session invalidation

**Files:**
- Modify: `app/controllers/concerns/authentication.rb`
- Create: `test/integration/session_invalidation_test.rb`

- [ ] **Step 1: Write failing test for session invalidation**

Create `test/integration/session_invalidation_test.rb`:
```ruby
require "test_helper"

class SessionInvalidationTest < ActionDispatch::IntegrationTest
  test "a signed-in session is invalidated when sessions_generation bumps" do
    user = users(:active_member)
    enroll_if_needed(user)
    sign_in_as(user)

    get root_path
    assert_response :success
    assert_match user.pseudonym, response.body

    # Simulate recovery completion on another device:
    user.update!(sessions_generation: user.sessions_generation + 1)

    get root_path
    assert_response :success
    refute_match user.pseudonym, response.body, "old session must be signed out"
  end
end
```

- [ ] **Step 2: Run test — expect red**

Run: `bin/test test/integration/session_invalidation_test.rb`

Expected: fails (the current `set_current_user` does not check `sessions_generation`).

- [ ] **Step 3: Update `app/controllers/concerns/authentication.rb`**

Replace `set_current_user` and `start_session_for` with:
```ruby
def set_current_user
  return if session[:user_id].blank?

  user = User.find_by(id: session[:user_id])

  if user && session[:sessions_generation] == user.sessions_generation
    Current.user = user
  else
    reset_session
  end
end

def start_session_for(user)
  reset_session
  session[:user_id] = user.id
  session[:sessions_generation] = user.sessions_generation
  Current.user = user
end
```

- [ ] **Step 4: Run test — expect green**

Run: `bin/test test/integration/session_invalidation_test.rb`

- [ ] **Step 5: Run broader controller tests to confirm no regression**

Run: `bin/test test/controllers/authentication_guards_test.rb test/controllers/enrollments_controller_test.rb`

Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/concerns/authentication.rb test/integration/session_invalidation_test.rb
git commit -m "Invalidate sessions on sessions_generation mismatch"
```

---

## Task 12: LoginFailureTracker — dedicated per-user test coverage

**Files:**
- Modify: `test/services/login_failure_tracker_test.rb` (create if absent)

**Note:** the per-user methods were added in Task 7. This task adds the dedicated service-level test coverage.

- [ ] **Step 1: Write tests**

Create or overwrite `test/services/login_failure_tracker_test.rb`:
```ruby
require "test_helper"

class LoginFailureTrackerTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "ip-scoped track increments count and blocked? respects IP_LIMIT" do
    LoginFailureTracker::IP_LIMIT.times { LoginFailureTracker.track("1.1.1.1") }
    assert LoginFailureTracker.blocked?("1.1.1.1")
    refute LoginFailureTracker.blocked?("2.2.2.2")
  end

  test "user-scoped track_user increments count and blocked_user? respects USER_LIMIT" do
    LoginFailureTracker::USER_LIMIT.times { LoginFailureTracker.track_user(42) }
    assert LoginFailureTracker.blocked_user?(42)
    refute LoginFailureTracker.blocked_user?(99)
  end

  test "reset and reset_user clear their own scope only" do
    LoginFailureTracker.track("1.1.1.1")
    LoginFailureTracker.track_user(42)

    LoginFailureTracker.reset("1.1.1.1")

    assert_equal 0, LoginFailureTracker.count("1.1.1.1")
    assert_equal 1, Rails.cache.read("login-failure:user:42").to_i
  end

  test "track tolerates blank arguments" do
    assert_nothing_raised do
      LoginFailureTracker.track(nil)
      LoginFailureTracker.track("")
      LoginFailureTracker.track_user(nil)
    end
  end
end
```

- [ ] **Step 2: Run tests — expect green (implementation already landed in Task 7)**

Run: `bin/test test/services/login_failure_tracker_test.rb`

- [ ] **Step 3: Commit**

```bash
git add test/services/login_failure_tracker_test.rb
git commit -m "Add per-user LoginFailureTracker test coverage"
```

---

## Task 13: Rack::Attack — recovery rate limits + sign-in reuse

**Files:**
- Modify: `config/initializers/rack_attack.rb`
- Modify: `test/integration/rate_limiting_test.rb` (add recovery tests)

- [ ] **Step 1: Update Rack::Attack**

In `config/initializers/rack_attack.rb`, replace the existing `blocklist("login_failures/ip")` block and add recovery throttles. Add the following alongside the existing throttles (after `throttle("sign_up/ip", ...)`):

```ruby
  blocklist("login_failures/ip") do |request|
    request.post? && request.path == "/sign-in" && LoginFailureTracker.blocked?(request.ip)
  end

  throttle("recoveries/ip", limit: 5, period: 1.hour) do |request|
    request.ip if request.post? && request.path == "/recover"
  end

  throttle("recoveries/email", limit: 3, period: 1.hour) do |request|
    if request.post? && request.path == "/recover"
      email = request.params.dig("recovery", "email").to_s.strip.downcase.presence
      "recovery:#{email}" if email
    end
  end
```

Keep the existing `authenticated_user_id`, `comment_creation_request?`, etc. helper methods.

- [ ] **Step 2: Add integration coverage for recovery throttle**

Append to `test/integration/rate_limiting_test.rb` (or create the file with minimal scaffolding if it's not already structured for this):
```ruby
test "recovery requests are throttled per IP" do
  Rack::Attack.enabled = true
  Rack::Attack.cache.store.clear

  user = users(:active_member)

  with_stubbed_turnstile_verification(true) do
    5.times do
      post recover_path, params: { recovery: { email: user.email } }
      assert_response :redirect
    end

    post recover_path, params: { recovery: { email: user.email } }
    assert_response 429
  end
ensure
  Rack::Attack.enabled = false
  Rack::Attack.cache.store.clear
end
```

- [ ] **Step 3: Run rate-limit tests — expect green**

Run: `bin/test test/integration/rate_limiting_test.rb`

- [ ] **Step 4: Commit**

```bash
git add config/initializers/rack_attack.rb test/integration/rate_limiting_test.rb
git commit -m "Throttle recovery requests per-IP and per-email via Rack::Attack"
```

---

## Task 14: Parameter filtering for TOTP codes

**Files:**
- Modify: `config/initializers/filter_parameter_logging.rb`

- [ ] **Step 1: Update the filter list**

In `config/initializers/filter_parameter_logging.rb`, change:
```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
```
to:
```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :code, :ssn, :cvv, :cvc
]
```

(`:code` is added so TOTP code parameters are redacted in logs. `:passw` is kept because Rails convention; it's harmless now that no password params exist.)

- [ ] **Step 2: Commit**

```bash
git add config/initializers/filter_parameter_logging.rb
git commit -m "Filter TOTP code parameter from request logs"
```

---

## Task 15: Locale cleanup — remove orphaned password/email-verification strings

**Files:**
- Modify: `config/locales/en.yml`

**Goal:** Delete all `auth.password_reset.*`, `auth.email_verification.*`, `mailers.user_mailer.email_verification.*`, `mailers.user_mailer.password_reset.*`, and password-related field labels now that no code references them.

- [ ] **Step 1: Delete the `auth.password_reset.*` subtree**

In `config/locales/en.yml`, find the `en:` → `auth:` → `password_reset:` block and remove the entire subtree. It looks approximately like:
```yaml
    password_reset:
      link: "Reset password"
      invalid: ...
      ...
```

- [ ] **Step 2: Delete `auth.email_verification.*` if present**

Same pattern — remove the `email_verification:` block under `auth:` if it exists (it may not; only remove if found).

- [ ] **Step 3: Delete old mailer locale keys**

Under `en:` → `mailers:` → `user_mailer:`, remove the `email_verification:` and `password_reset:` subtrees.

- [ ] **Step 4: Delete password field labels**

Under `en:` → `auth:` → `fields:`, remove:
```yaml
      password: "Password"
      password_confirmation: "Confirm password"
```

Also search globally in `en.yml` for any remaining `password:` or `password_confirmation:` field labels (e.g., in `activerecord.attributes.user`) and remove them.

- [ ] **Step 4b: Rename the pending state enum key in the locale**

Search `config/locales/en.yml` for every occurrence of `pending_email_verification:` used as a key under an `account_states:` block (typically `nav.account_states` and `auth.guards.account_states`). Rename each to `pending_enrollment:`. Keep the English label generic — e.g. `"Pending enrollment"` or `"Setup not complete"` — since the gate is now TOTP enrollment, not email verification.

Example change under `en:` → `nav:` → `account_states:`:
```yaml
# before
      account_states:
        active: "Active"
        pending_email_verification: "Pending email verification"
        suspended: "Suspended"
        banned: "Banned"

# after
      account_states:
        active: "Active"
        pending_enrollment: "Setup not complete"
        suspended: "Suspended"
        banned: "Banned"
```

Same transformation anywhere else `pending_email_verification` appears as a key (not a value).

- [ ] **Step 5: Run the full test suite to catch missing-locale errors**

Run: `bin/test`

Expected: any failure referring to missing `auth.password_reset` / `auth.email_verification` / `mailers.user_mailer.password_reset` / `mailers.user_mailer.email_verification` points to a place where code still references the deleted keys. Chase down each reference and delete the dead code.

If `I18n::MissingTranslation` surfaces in unexpected places (e.g., flash notices), those are candidate orphan references in views or controllers — delete them or update to new keys.

- [ ] **Step 6: Commit**

```bash
git add config/locales/en.yml
git commit -m "Remove orphaned password/email-verification locale keys"
```

---

## Task 16: Delete obsolete controllers and their tests

**Files:**
- Delete: `app/controllers/password_resets_controller.rb`
- Delete: `app/controllers/email_verifications_controller.rb`
- Delete: `app/views/password_resets/new.html.erb`
- Delete: `app/views/password_resets/edit.html.erb`
- Delete: `test/integration/password_reset_flow_test.rb`

- [ ] **Step 1: Delete the files**

```bash
rm app/controllers/password_resets_controller.rb
rm app/controllers/email_verifications_controller.rb
rm app/views/password_resets/new.html.erb
rm app/views/password_resets/edit.html.erb
rm test/integration/password_reset_flow_test.rb

# Remove the empty password_resets view directory
rmdir app/views/password_resets 2>/dev/null || true
```

- [ ] **Step 2: Verify nothing references the deleted classes**

Run: `grep -R -l "PasswordResetsController\|EmailVerificationsController\|password_reset_path\|password_reset_token_path\|email_verification_path" app test config`

Expected: no results. If there are any, delete or update those references.

- [ ] **Step 3: Run full suite**

Run: `bin/test`

Expected: several integration tests still broken (those covering sign-up, session, email-verification, enrollment flows) — they're rewritten in Task 17.

- [ ] **Step 4: Commit**

```bash
git add -A app/controllers app/views/password_resets test/integration
git commit -m "Remove PasswordResetsController and EmailVerificationsController"
```

---

## Task 17: Integration test suite rewrite

**Files:**
- Rewrite: `test/integration/sign_up_flow_test.rb`
- Delete: `test/integration/session_flow_test.rb`
- Create: `test/integration/sign_in_flow_test.rb`
- Delete: `test/integration/email_verification_flow_test.rb`
- Create: `test/integration/enrollment_flow_test.rb`
- Create: `test/integration/recovery_flow_test.rb`
- Modify: `test/controllers/authentication_guards_test.rb` (state-enum rename; no logic change)

- [ ] **Step 1: Delete obsolete test files**

```bash
rm test/integration/session_flow_test.rb
rm test/integration/email_verification_flow_test.rb
```

- [ ] **Step 2: Rewrite `test/integration/sign_up_flow_test.rb`**

Replace contents with:
```ruby
require "test_helper"

class SignUpFlowTest < ActionDispatch::IntegrationTest
  test "sign-up creates a pending_enrollment user, enqueues enrollment email, and does not start a session" do
    with_stubbed_turnstile_verification(true) do
      assert_enqueued_emails 1 do
        assert_difference -> { User.count }, 1 do
          post sign_up_path, params: {
            user: { pseudonym: "newbie", email: "newbie@example.com" },
            **spam_check_params(:sign_up)
          }
        end
      end
    end

    user = User.order(:created_at).last
    assert user.pending_enrollment?
    assert_nil user.totp_secret
    assert_redirected_to sign_in_path
    assert_nil session[:user_id], "sign-up must not create a session"
  end

  test "sign-up with a disposable email is rejected" do
    with_stubbed_turnstile_verification(true) do
      assert_no_difference -> { User.count } do
        post sign_up_path, params: {
          user: { pseudonym: "spammer", email: "spammer@mailinator.com" },
          **spam_check_params(:sign_up)
        }
      end
    end

    assert_response :unprocessable_entity
  end

  test "sign-up with failed Turnstile is rejected" do
    with_stubbed_turnstile_verification(false) do
      assert_no_difference -> { User.count } do
        post sign_up_path, params: {
          user: { pseudonym: "newbie", email: "newbie@example.com" },
          **spam_check_params(:sign_up)
        }
      end
    end

    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 3: Create `test/integration/sign_in_flow_test.rb`**

```ruby
require "test_helper"

class SignInFlowTest < ActionDispatch::IntegrationTest
  test "active user signs in with email + valid TOTP code" do
    user = users(:active_member)
    enroll_if_needed(user)

    post sign_in_path, params: {
      session: { email: user.email, code: valid_totp_code_for(user) }
    }

    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end

  test "wrong code shows generic error and does not sign in" do
    user = users(:active_member)
    enroll_if_needed(user)

    post sign_in_path, params: {
      session: { email: user.email, code: "000000" }
    }

    assert_redirected_to sign_in_path
    assert_nil session[:user_id]
  end

  test "unknown email shows the same generic error" do
    post sign_in_path, params: {
      session: { email: "nobody@example.com", code: "123456" }
    }

    assert_redirected_to sign_in_path
    assert_equal I18n.t("auth.sign_in.invalid_credentials"), flash[:alert]
  end

  test "pending_enrollment user cannot sign in" do
    user = users(:pending_member)
    # note: pending user has no totp_secret, so no code will validate

    post sign_in_path, params: {
      session: { email: user.email, code: "123456" }
    }

    assert_redirected_to sign_in_path
    assert_nil session[:user_id]
  end

  test "suspended user is shown a blocked message" do
    user = users(:suspended_member)

    post sign_in_path, params: {
      session: { email: user.email, code: "123456" }
    }

    assert_redirected_to sign_in_path
    assert_match I18n.t("auth.guards.account_states.suspended"), flash[:alert]
  end

  test "replayed TOTP code is rejected on second use" do
    user = users(:active_member)
    enroll_if_needed(user)
    code = valid_totp_code_for(user)

    post sign_in_path, params: { session: { email: user.email, code: code } }
    assert_redirected_to root_path

    delete sign_out_path
    assert_nil session[:user_id]

    post sign_in_path, params: { session: { email: user.email, code: code } }
    assert_redirected_to sign_in_path, "replayed code must not sign in"
  end
end
```

- [ ] **Step 4: Create `test/integration/enrollment_flow_test.rb`**

```ruby
require "test_helper"

class EnrollmentFlowTest < ActionDispatch::IntegrationTest
  test "full happy path: sign-up -> email -> enroll -> signed in" do
    perform_enqueued_jobs do
      with_stubbed_turnstile_verification(true) do
        post sign_up_path, params: {
          user: { pseudonym: "newbie", email: "newbie@example.com" },
          **spam_check_params(:sign_up)
        }
      end
    end

    user = User.find_by!(email: "newbie@example.com")
    mail = ActionMailer::Base.deliveries.last
    token = mail.body.encoded[%r{/enroll/([A-Za-z0-9_\-]+)}, 1]
    assert token.present?

    # GET the enrollment page
    get enroll_path(token: token)
    assert_response :success
    assert user.reload.totp_candidate_secret.present?

    # Submit a valid code
    code = ROTP::TOTP.new(user.totp_candidate_secret).now
    post enroll_confirm_path(token: token), params: { enrollment: { code: code } }

    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
    user.reload
    assert user.active?
    assert user.totp_secret.present?
    assert_nil user.totp_candidate_secret
  end

  test "refreshing the enrollment page keeps the same candidate" do
    user = users(:pending_member)
    token = user.generate_token_for(:enrollment)

    get enroll_path(token: token)
    first_secret = user.reload.totp_candidate_secret

    get enroll_path(token: token)
    second_secret = user.reload.totp_candidate_secret

    assert_equal first_secret, second_secret
  end

  test "expired token redirects to sign-in" do
    user = users(:pending_member)
    token = user.generate_token_for(:enrollment)

    travel 31.minutes do
      get enroll_path(token: token)
    end

    assert_redirected_to sign_in_path
  end
end
```

- [ ] **Step 5: Create `test/integration/recovery_flow_test.rb`**

```ruby
require "test_helper"

class RecoveryFlowTest < ActionDispatch::IntegrationTest
  test "lost phone: request recovery, click link, re-enroll, signed in with new secret" do
    user = users(:active_member)
    enroll_if_needed(user)
    original_secret = user.totp_secret

    perform_enqueued_jobs do
      with_stubbed_turnstile_verification(true) do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    mail = ActionMailer::Base.deliveries.last
    token = mail.body.encoded[%r{/enroll/([A-Za-z0-9_\-]+)}, 1]

    # Visiting the link must NOT mutate totp_secret
    get enroll_path(token: token)
    user.reload
    assert_equal original_secret, user.totp_secret, "old authenticator must still work during recovery"
    assert user.totp_candidate_secret.present?

    # Submit a valid code against the new candidate
    new_code = ROTP::TOTP.new(user.totp_candidate_secret).now
    post enroll_confirm_path(token: token), params: { enrollment: { code: new_code } }

    assert_redirected_to root_path
    user.reload
    refute_equal original_secret, user.totp_secret
    assert_nil user.totp_candidate_secret
  end

  test "recovery bumps sessions_generation so other-device sessions are signed out" do
    user = users(:active_member)
    enroll_if_needed(user)

    perform_enqueued_jobs do
      with_stubbed_turnstile_verification(true) do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end

    token = ActionMailer::Base.deliveries.last.body.encoded[%r{/enroll/([A-Za-z0-9_\-]+)}, 1]
    get enroll_path(token: token)
    code = ROTP::TOTP.new(user.reload.totp_candidate_secret).now

    before = user.sessions_generation
    post enroll_confirm_path(token: token), params: { enrollment: { code: code } }

    assert_equal before + 1, user.reload.sessions_generation
  end

  test "recovery works for pending_enrollment users as a resend of the enrollment email" do
    user = users(:pending_member)

    with_stubbed_turnstile_verification(true) do
      assert_enqueued_emails 1 do
        post recover_path, params: { recovery: { email: user.email } }
      end
    end
  end
end
```

- [ ] **Step 6: Update `test/controllers/authentication_guards_test.rb`**

In the file, find and update any reference to the old state name:
```ruby
# OLD
user.update!(state: :pending_email_verification)

# NEW
user.update!(state: :pending_enrollment)
```

And fixtures usage: fixture names stay the same (`pending_member`) but the underlying state name changed. No other logic changes.

- [ ] **Step 7: Run full integration layer**

Run: `bin/test test/integration test/controllers`

Expected: all tests green. If anything is red, chase it down (usually stale locale keys or dangling references).

- [ ] **Step 8: Commit**

```bash
git add test/integration test/controllers/authentication_guards_test.rb
git commit -m "Rewrite auth integration tests for TOTP sign-up/sign-in/enrollment/recovery"
```

---

## Task 18: PLAN.md updates (7 sections)

**Files:**
- Modify: `PLAN.md`

**Goal:** Update PLAN.md to match the design per spec §3. Seven sections change.

- [ ] **Step 1: Update §2, non-negotiable #2**

Find:
```
2. Email and password authentication is required in v1.
```

Replace with:
```
2. Email and authenticator-app (TOTP) authentication is required in v1. No passwords.
```

- [ ] **Step 2: Update §5.1 User required fields**

Find the "Required fields:" block under §5.1 Users. Replace:
```
3. `password_digest`
```
with (in place at position 3):
```
3. `totp_secret`
```

And append after the existing required fields:
```
8. `totp_candidate_secret`
9. `totp_candidate_secret_expires_at`
10. `totp_last_used_counter`
11. `sessions_generation`
12. `enrollment_token_generation`
```

Also update the `state` enum bullet under "Rules:" to reference the new state name:
```
6. `state` enum:
   1. `pending_enrollment`
```

- [ ] **Step 3: Rewrite §6.7 Authentication**

Replace the entire §6.7 block with:
```
### 6.7 Authentication

V1 auth includes:
1. sign up
2. sign in
3. sign out
4. TOTP enrollment via email-verified link
5. TOTP recovery via email-verified link
6. session management

Rules:
1. Sign-up collects email and pseudonym only. No password field exists.
2. A sign-up creates a `pending_enrollment` user and enqueues an enrollment email. No session is started.
3. Clicking the enrollment link lands the user on a QR + code-entry page. Scanning the QR with any authenticator app (Duo, Google Authenticator, Authy, 1Password, etc.) provisions the TOTP secret.
4. On successful code entry, the account transitions to `active` and a session starts.
5. Sign-in accepts email + 6-digit TOTP code on a single form.
6. TOTP codes are single-use: a replayed code within its 30-second validity window is rejected.
7. A "Recover access" link on the sign-in page sends a new enrollment email, which re-enrolls the authenticator. The old secret is not rotated until the user confirms a new code (recovery is reversible mid-flow).
8. Recovery completion invalidates all other sessions for the user via the `sessions_generation` counter.
9. No social login, no passkeys, no phone verification, no mandatory real-name fields.
10. The enrollment/recovery email link is not a sign-in magic link — it only gates access to TOTP setup; the user still must enter a valid TOTP code to complete sign-in.
```

- [ ] **Step 4: Update §6.9 Rate limiting**

Find:
```
2. login failures:
   1. 10 per IP per 15 minutes
```

Replace with:
```
2. sign-in code attempts:
   1. 10 per IP per 15 minutes
   2. 5 per user per 15 minutes
3. recovery email requests:
   1. 5 per IP per hour
   2. 3 per email per hour
```

And renumber the subsequent items accordingly so "post creation:" becomes #4, "comment creation:" becomes #5, etc.

- [ ] **Step 5: Update §7 Routes**

Find and remove:
```
13. `/password-reset`
14. `/password-reset/:token`
15. `/email-verification/:token`
```

Add in their place:
```
13. `/recover`
14. `/recover/:token`
15. `/enroll/:token`
```

- [ ] **Step 6: Update §10 Package C outputs and "Done when"**

Find the Package C "Outputs:" block and replace the password-reset items. New block:
```
Outputs:
1. `User` model
2. signed-cookie session auth with sessions_generation invalidation
3. sign-up (email + pseudonym only)
4. TOTP enrollment via email-verified link
5. sign-in (email + TOTP code, single form)
6. TOTP recovery (re-enrollment via email-verified link)
7. role and state guards
8. Turnstile verification service
9. account-state restrictions on post, comment, and vote actions
```

Replace the "Done when:" block:
```
Done when:
1. sign up creates a pending_enrollment user and sends an enrollment email
2. completing enrollment activates the account and starts a session
3. sign in works with email + TOTP code
4. recovery works end-to-end (email link → new QR → new session; old sessions invalidated)
5. replayed TOTP codes are rejected
6. suspended and banned users are blocked from sign-in and guarded surfaces
7. tests cover auth flows and permission gates
```

- [ ] **Step 7: Update §14 Testing Strategy**

Find the "Must-have automated coverage:" list and make these replacements:
- Replace `3. password reset` with `3. TOTP enrollment flow`
- Replace `2. email verification` with `2. recovery flow (TOTP re-enrollment via email)`
- Append:
```
13. TOTP replay prevention
14. session invalidation on recovery completion
15. candidate-secret reversibility (abandoned recovery leaves old authenticator working)
```

Find "Must-have system tests:" → change:
- `2. sign up and verify` → `2. sign up and enroll TOTP`

- [ ] **Step 8: Commit**

```bash
git add PLAN.md
git commit -m "Update PLAN.md to reflect TOTP-only authentication"
```

---

## Task 19: Write the documentation

**Files:**
- Create: `docs/package-c2-totp-auth-replacement.md`

- [ ] **Step 1: Create the doc**

Create `docs/package-c2-totp-auth-replacement.md` following the pattern of `docs/package-c-auth-and-account-lifecycle.md`:

```markdown
# Package C2: TOTP Authentication Replacement

## What Changed

Replaced password-based authentication with TOTP-only authenticator-app sign-in. After this change, the site never stores user-controlled passwords; instead, each active user has an encrypted TOTP secret and authenticates by entering a 6-digit code from any standard authenticator app (Duo, Google Authenticator, Authy, 1Password, etc.).

Sign-up collects email and pseudonym only and creates a `pending_enrollment` user; the account becomes `active` after the user clicks the enrollment email link and confirms a code from their newly provisioned authenticator. The same enrollment page serves both first-time setup and lost-device recovery.

## Files Added or Modified

### Runtime additions
- `app/controllers/enrollments_controller.rb`
- `app/controllers/recoveries_controller.rb`
- `app/views/enrollments/show.html.erb`
- `app/views/recoveries/new.html.erb`
- `app/views/user_mailer/enrollment_link.html.erb`
- `app/views/user_mailer/enrollment_link.text.erb`
- `app/javascript/controllers/totp_countdown_controller.js`
- `db/migrate/<timestamp>_replace_password_with_totp.rb`

### Runtime modifications
- `Gemfile`, `Gemfile.lock` — added `rotp`, `rqrcode`; removed `bcrypt`
- `app/models/user.rb` — encrypts TOTP attributes; TOTP and enrollment methods; renamed `pending_email_verification` state to `pending_enrollment`
- `app/controllers/sessions_controller.rb` — email + TOTP single-form sign-in with per-IP and per-user rate limits
- `app/controllers/users_controller.rb` — email + pseudonym sign-up, no password, no auto-session
- `app/controllers/concerns/authentication.rb` — `sessions_generation`-based session invalidation
- `app/mailers/user_mailer.rb` — replaced `email_verification` and `password_reset` with `enrollment_link`
- `app/services/login_failure_tracker.rb` — per-user scope alongside per-IP
- `config/routes.rb` — replaced password-reset + email-verification routes with `/recover`, `/recover/:token`, `/enroll/:token`
- `config/initializers/rack_attack.rb` — added recovery email rate limits
- `config/initializers/filter_parameter_logging.rb` — added `:code`
- `config/locales/en.yml` — auth/enrollment/recovery/totp copy

### Tests
- Added: `enrollment_flow_test`, `sign_in_flow_test`, `recovery_flow_test`, `session_invalidation_test`, `enrollments_controller_test`, `recoveries_controller_test`, `login_failure_tracker_test` (per-user coverage)
- Rewritten: `sign_up_flow_test`, `user_test`
- Removed: `password_reset_flow_test`, `email_verification_flow_test`, `session_flow_test`

### Deletions
- `app/controllers/password_resets_controller.rb`
- `app/controllers/email_verifications_controller.rb`
- `app/views/password_resets/`
- `app/views/user_mailer/password_reset.*.erb`
- `app/views/user_mailer/email_verification.*.erb`

## Verification

```bash
bin/test
bin/lint
bin/security
```

All green.

### Manual smoke-test walkthrough

1. `bin/dev` then visit `/sign-up`.
2. Sign up with a test email and pseudonym.
3. Open the mailer preview (or check the development SMTP logs) for the enrollment link.
4. Click the link → QR code renders.
5. Scan with any authenticator app.
6. Enter the 6-digit code → redirected to root, signed in.
7. Sign out.
8. Sign in from `/sign-in` with email + current code → success.
9. Submit the same code twice (two sign-in attempts within 30s) → second rejected (replay prevention).
10. Click "Recover access" → submit email → check for new email → click link → QR changes → enter code from newly scanned device → signed in; session on the prior device is signed out on next request.

## Follow-up Work and Limitations

- Voluntary TOTP rotation via settings is not implemented (the recovery flow covers the need).
- No backup / paper recovery codes — email is the recovery mechanism.
- No sweep job for abandoned pending-enrollment rows; rely on Turnstile + the narrow attack surface for v1.
- `RAILS_MASTER_KEY` + DB leakage remains the worst-case compromise vector for TOTP secrets; this is documented in the design spec §2 as an accepted trade-off.
- Documentation of the `bin/rails db:encryption:init` setup lives in Task 1 of the plan and the design spec §7.
```

- [ ] **Step 2: Commit**

```bash
git add docs/package-c2-totp-auth-replacement.md
git commit -m "Document TOTP auth replacement (Package C2)"
```

---

## Task 20: Final verification

**Files:** none modified in this task; verification only.

- [ ] **Step 1: Full test suite**

Run: `bin/test`

Expected: all green. If anything fails, debug and fix (typical causes: lingering locale references, un-renamed state enum values, dangling route helpers).

- [ ] **Step 2: Lint**

Run: `bin/lint`

Expected: exit 0.

- [ ] **Step 3: Security scan**

Run: `bin/security`

Expected: exit 0 (Brakeman + bundler-audit clean).

- [ ] **Step 4: Boot check**

Run: `bin/rails runner "puts 'boots'"`

Expected: `boots` printed — confirms the app initializes cleanly with the new encryption and routes.

- [ ] **Step 5: Manual smoke test via `bin/dev`**

Run: `bin/dev`

Walk through the manual verification steps documented in Task 19 Step 1. Each step should behave as described. If any step fails, file a follow-up task rather than retrofitting into this plan.

- [ ] **Step 6: No commit (clean verification task)**

If any fixes were needed, they would have been committed in their own task. This task produces no new commits unless fixes were necessary.

---

## Self-Review Completed

**1. Spec coverage:**
- Spec §3 PLAN.md changes (7 sections): Task 18 ✓
- Spec §4 Architecture (gems, controllers): Tasks 2, 7, 8 ✓
- Spec §5 Data model: Tasks 2, 4, 5 ✓
- Spec §6 User flows (enrollment, sign-in, recovery, session invalidation): Tasks 7, 8, 9, 10, 11, 17 ✓
- Spec §7 Security, rate limiting, encryption, TOTP countdown, param filtering: Tasks 1, 5, 7, 9, 13, 14 ✓
- Spec §8 Testing strategy (deleted/modified/added): Tasks 6, 12, 15, 16, 17 ✓
- Spec §9 File impact: covered by all tasks collectively ✓
- Spec §10 Prerequisites: Task 1 ✓
- Spec §11 Definition of Done: Task 20 ✓

**2. Placeholder scan:** no `TBD`/`TODO`/`add appropriate...`/`similar to Task N`. All code blocks complete.

**3. Type consistency:** Method names checked across tasks: `begin_enrollment!`, `complete_enrollment!`, `verify_totp`, `totp` all consistent. `LoginFailureTracker.track_user` / `blocked_user?` / `reset_user` consistent across Tasks 7, 9, 12. Locale keys (`auth.enrollment.*`, `auth.recovery.*`, `auth.sign_in.*`, `auth.totp.*`) consistent across tasks.
