# Package C: Auth and Account Lifecycle

## What Changed

Implemented the first complete account system for the application. The codebase now includes a `User` model with pseudonym, email, password, role, state, verification, and reply-alert fields; signed-cookie session auth; sign-up, sign-in, and sign-out flows; email verification; password reset; account-state guards for future interactive routes; a Turnstile verification service for sign-up; and transactional mailers for verification and password-reset emails.

The shared shell from Package B was extended to support auth navigation, flash notices, and restrained form layouts without breaking the locale-backed copy registry or visual constraints from `PLAN.md`.

## Files Added or Modified

### Model and Persistence
- `Gemfile` / `Gemfile.lock` — enabled `bcrypt` for `has_secure_password`
- `db/migrate/20260421163000_create_users.rb` — added the `users` table and `citext` indexes for case-insensitive uniqueness
- `app/models/user.rb` — added enums, validations, normalization, verification helpers, password-reset permissions, and token generation
- `app/models/current.rb` — added current-request user storage

### Auth Infrastructure
- `app/controllers/concerns/authentication.rb` — added signed-cookie session helpers and auth/account-state guards
- `app/controllers/application_controller.rb` — wired auth concern and Turnstile site-key helper into the app controller
- `config/routes.rb` — added sign-up, sign-in, sign-out, password-reset, and email-verification routes

### Auth Controllers and Mailers
- `app/controllers/users_controller.rb` — sign-up form and account creation
- `app/controllers/sessions_controller.rb` — sign-in and sign-out
- `app/controllers/email_verifications_controller.rb` — token-based email verification without magic-link sign-in
- `app/controllers/password_resets_controller.rb` — password-reset request, token validation, and password update flow
- `app/services/turnstile_verification.rb` — server-side Turnstile verification service
- `app/mailers/application_mailer.rb` — switched to env-driven sender address fallback
- `app/mailers/user_mailer.rb` — verification and password-reset emails
- `app/views/user_mailer/*.erb` — email bodies for verification and password reset

### UI and Locale Registry
- `app/views/shared/_site_nav.html.erb` — added account-aware navigation states
- `app/views/shared/_form_errors.html.erb` — shared error summary partial
- `app/views/users/new.html.erb` — sign-up page
- `app/views/sessions/new.html.erb` — sign-in page
- `app/views/password_resets/new.html.erb` — password-reset request page
- `app/views/password_resets/edit.html.erb` — password-reset update page
- `app/assets/stylesheets/application.css` — added restrained auth and form styles
- `config/locales/en.yml` — added auth, form, mailer, and validation copy
- `.env.example` — added `MAILER_FROM`

### Tests and Fixtures
- `test/fixtures/users.yml` — added auth/account fixtures
- `test/test_helper.rb` — added auth and environment helpers for tests
- `test/models/user_test.rb` — model validation and state-behavior coverage
- `test/services/turnstile_verification_test.rb` — Turnstile service coverage
- `test/mailers/user_mailer_test.rb` — verification and password-reset mailer coverage
- `test/integration/sign_up_flow_test.rb` — sign-up and Turnstile-failure coverage
- `test/integration/session_flow_test.rb` — sign-in/sign-out and blocked-state coverage
- `test/integration/email_verification_flow_test.rb` — verification success and blocked/invalid cases
- `test/integration/password_reset_flow_test.rb` — password-reset request/update and blocked/invalid cases
- `test/controllers/authentication_guards_test.rb` — future interaction guard coverage for anonymous, pending, suspended, banned, and active users

## Verification

### Environment and Database Preparation
```bash
docker compose run --rm app bin/setup
```
Result: gems installed, the `users` table was migrated in development and test databases, and PostgreSQL `citext` was enabled successfully.

### Automated Checks
```bash
docker compose run --rm app bin/test
docker compose run --rm app bin/lint
docker compose run --rm app bin/security
```
Result: all commands completed successfully after the Package C changes.

### Auth and Copy Registry Review
Verified through tests and source inspection that:
- sign-up, sign-in, sign-out, email verification, and password reset flows all render and execute successfully
- unverified users are blocked from guarded interaction surfaces
- suspended and banned users are blocked from sign-in and guarded interaction surfaces
- email verification does not create a passwordless session
- visible auth copy is sourced from `config/locales/en.yml`
- no hardcoded flash or visible ERB strings were introduced in auth controllers or views

## Follow-up Work and Limitations

- Turnstile verification is fully implemented server-side, but real production enforcement still requires user-provided Turnstile keys.
- SMTP delivery remains environment-driven; production mail sending still depends on user-provided Resend credentials.
- Rate limiting, honeypots, minimum-submit-time heuristics, and disposable-email blocking belong to Package J and are not implemented yet.
- Auth guards are ready for post/comment/vote controllers, but those interactive surfaces do not exist until later packages.
- Profile pages and moderator account-management interfaces remain out of scope until later packages.
