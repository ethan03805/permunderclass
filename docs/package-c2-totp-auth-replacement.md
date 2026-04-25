# Package C2: TOTP Authentication Replacement

## What Changed

Replaced password-based authentication with TOTP-only authenticator-app sign-in. After this change, the site never stores user-controlled passwords; instead, each active user has an encrypted TOTP secret and authenticates by entering a 6-digit code from any standard authenticator app (Duo, Google Authenticator, Authy, 1Password, etc.).

Sign-up collects email and pseudonym only and creates a `pending_enrollment` user; the account becomes `active` after the user clicks the enrollment email link and confirms a code from their newly provisioned authenticator. The same enrollment page serves both first-time setup and lost-device recovery — one code path handles both lifecycles.

Session invalidation on recovery is enforced via a `sessions_generation` counter stamped into the session cookie and compared on every request.

## Files Added or Modified

### Runtime additions
- `app/controllers/enrollments_controller.rb` — shared enrollment/recovery controller with QR + code confirmation
- `app/controllers/recoveries_controller.rb` — "I lost my authenticator" request page
- `app/views/enrollments/show.html.erb`
- `app/views/recoveries/new.html.erb`
- `app/views/user_mailer/enrollment_link.html.erb`
- `app/views/user_mailer/enrollment_link.text.erb`
- `app/javascript/controllers/totp_countdown_controller.js` — live 30-second TOTP countdown on sign-in and enrollment pages
- `db/migrate/20260424210140_replace_password_with_totp.rb`

### Runtime modifications
- `Gemfile`, `Gemfile.lock` — added `rotp ~> 6.3`, `rqrcode ~> 2.2`; removed `bcrypt`
- `app/models/user.rb` — `encrypts :totp_secret` + `:totp_candidate_secret`; TOTP methods (`totp`, `verify_totp`, `begin_enrollment!`, `complete_enrollment!`); `generates_token_for :enrollment`; state rename `pending_email_verification` → `pending_enrollment`; removed `has_secure_password` and related password validations/methods
- `app/controllers/sessions_controller.rb` — email + TOTP single-form sign-in with per-IP and per-user rate limits
- `app/controllers/users_controller.rb` — email + pseudonym sign-up, no password, no auto-session, redirect-and-email
- `app/controllers/concerns/authentication.rb` — `sessions_generation`-based session invalidation in `set_current_user`; stamping in `start_session_for`; updated state predicates
- `app/mailers/user_mailer.rb` — replaced `email_verification` and `password_reset` with `enrollment_link`
- `app/services/login_failure_tracker.rb` — per-user scope alongside per-IP (`blocked_user?`, `track_user`, `reset_user`)
- `app/views/posts/show.html.erb` — updated state predicate reference
- `config/application.rb` — loads Active Record encryption keys from `ACTIVE_RECORD_ENCRYPTION_*` env vars; sets `config.x.totp_issuer`
- `config/routes.rb` — removed `/password-reset` + `/email-verification/:token`; added `/recover`, `/recover/:token`, `/enroll/:token`
- `config/initializers/rack_attack.rb` — added recovery email rate limits (5/IP/hr, 3/email/hr)
- `config/initializers/filter_parameter_logging.rb` — added `:code` to the redaction list
- `config/locales/en.yml` — auth/enrollment/recovery/totp copy; removed orphaned password/email-verification keys; renamed `pending_email_verification` → `pending_enrollment` in `account_states` blocks
- `docker-compose.yml` — forwards `ACTIVE_RECORD_ENCRYPTION_*` env vars into app and worker containers
- `.env.example` — documented the three encryption-key env vars
- `PLAN.md` — seven sections updated (non-negotiable #2, §5.1, §6.7, §6.9, §7, §10, §14)

### Tests
- Added: `test/integration/enrollment_flow_test.rb`, `test/integration/sign_in_flow_test.rb`, `test/integration/recovery_flow_test.rb`, `test/integration/session_invalidation_test.rb`, `test/controllers/enrollments_controller_test.rb`, `test/controllers/recoveries_controller_test.rb`, `test/services/login_failure_tracker_test.rb`
- Rewritten: `test/integration/sign_up_flow_test.rb`, `test/models/user_test.rb`, `test/mailers/user_mailer_test.rb`, `test/test_helper.rb` (TOTP helpers)
- Removed: `test/integration/password_reset_flow_test.rb`, `test/integration/session_flow_test.rb` (replaced by `sign_in_flow_test.rb`), `test/integration/email_verification_flow_test.rb` (replaced by `enrollment_flow_test.rb`)

### Deletions
- `app/controllers/password_resets_controller.rb`
- `app/controllers/email_verifications_controller.rb`
- `app/views/password_resets/` (entire directory)
- `app/views/user_mailer/password_reset.{html,text}.erb`
- `app/views/user_mailer/email_verification.{html,text}.erb` (replaced by `enrollment_link.*`)

## Verification

### Environment setup (one-time, per developer)

1. Run `docker compose run --rm app bin/rails db:encryption:init` locally and capture the three 64-character keys it prints.
2. Add them to `.env` in the project root as `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` (see `.env.example`).
3. `.env` is gitignored; keys stay local. For production (Render), set the same three env vars in the dashboard.

### Automated test suite

```
docker compose run --rm app bundle exec rails test
```

Result at the last task's commit: `273 runs, 941 assertions, 0 failures, 0 errors, 0 skips`.

### Manual smoke-test walkthrough (to run after deploying or on a fresh dev DB)

1. `docker compose up` (or `bin/dev` outside Docker) then visit `/sign-up`.
2. Sign up with a test email + pseudonym; Turnstile bypassed in dev.
3. Inspect the mailer preview at `/rails/mailers` (or check the development SMTP capture) for the enrollment link.
4. Click the link → QR code renders.
5. Scan with any authenticator app (Duo, Google Authenticator, 1Password, etc.).
6. Enter the 6-digit code → redirected to root, signed in.
7. Sign out.
8. Sign in from `/sign-in` with email + current code → success.
9. Submit the same code twice within 30s (two sign-in attempts): second rejected (replay prevention).
10. Click "Recover access" → submit email → check for new email → click link → QR changes → enter code from newly scanned device → signed in; any existing session on the prior device is invalidated on its next request.

## Follow-up Work and Limitations

- **Voluntary TOTP rotation via settings** is not implemented. Users rotate their authenticator by running the recovery flow. If this becomes common enough to warrant a "change my authenticator" link in account settings, it's a narrow addition — the underlying `begin_enrollment!` / `complete_enrollment!` methods already handle the rotation safely.
- **No backup / paper recovery codes.** Email is the recovery mechanism. If a user loses both their authenticator and their email access, an admin must intervene manually. This is acknowledged per the design trade-off in `docs/superpowers/specs/2026-04-24-totp-only-auth-design.md` §2.
- **Candidate-secret expiry not enforced in `complete_enrollment!`.** The outer 30-minute enrollment token TTL provides the effective upper bound, but `complete_enrollment!` itself does not check `totp_candidate_secret_expires_at`. Low-risk; consider tightening if future flows allow longer-lived candidates.
- **No sweep job for abandoned `pending_enrollment` rows.** They hold their `(email, pseudonym)` uniqueness indefinitely. Turnstile on sign-up throttles bulk-abandonment; a periodic cleanup job can be added if abuse materializes post-launch.
- **`RAILS_MASTER_KEY` + DB leak compromises all TOTP secrets.** Same trust model as any symmetric-key-at-rest scheme; documented as an accepted trade-off in the design spec §2.
- **One-time Active Record encryption key setup** must precede any deployment that runs the migration. Keys stored in credentials OR env vars (we use env vars via `config/application.rb`'s explicit `ENV.fetch` calls, so Rails credentials are not required).
