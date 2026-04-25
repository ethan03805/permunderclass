# Passwordless TOTP Authentication — Design

**Status:** Approved design, ready for implementation planning
**Date:** 2026-04-24
**Branch:** `Password---MFA-Replacement-Test-EXPERIMENTAL`
**Supersedes:** Password-based authentication from Package C

---

## 1. Overview

Replace `has_secure_password` and the password-reset flow with TOTP (RFC 6238) authentication using any standard authenticator app (Duo, Google Authenticator, Authy, 1Password, etc.). After this change, `permanentunderclass.me` never stores or handles user passwords.

**Migration approach:** big-bang. The site is not yet launched, so no user migration is required. One branch removes all password code and lands the TOTP stack in place.

**Scope constraints:**
- TOTP-only (single factor). No password, no WebAuthn, no passkeys, no social login.
- Email-based recovery for lost devices (narrow enrollment token; not a sign-in magic link).
- No "remember me" beyond the existing Rails signed-cookie session lifetime.
- No voluntary in-settings TOTP regeneration in v1 — the recovery flow covers that need.

---

## 2. Goals and Acknowledged Trade-offs

**Stated goal:** reduce the burden of storing user-controlled sensitive data (passwords) and remove password-reuse risk from this site's attack surface.

**Trade-offs explicitly accepted:**

1. **Different leak profile, not strictly smaller.** `password_digest` (bcrypt hash) is one-way — a DB leak forces per-password brute force. `totp_secret` is a symmetric key encrypted under `RAILS_MASTER_KEY` — if *both* the DB and the master key leak, every account is compromised instantly. Different risk, not smaller.
2. **Email inbox compromise = account takeover.** Recovery intentionally trusts email; if an attacker controls the inbox, they can enroll their own authenticator.
3. **Suspended/banned sign-in shows a specific error.** Minimally leaks account existence. Preserves current UX.

**User wins:**
- No password-reuse cascade from other sites' breaches.
- No "strong password" UX burden on users.
- No password-reset email as a phishing target.
- Smaller, more uniform auth codebase after the change (one enrollment page serves both sign-up and recovery).

---

## 3. PLAN.md Changes (7 sections)

| Section | Change |
|---|---|
| §2, non-negotiable #2 | Rewrite: "Email and authenticator-app (TOTP) authentication. No passwords." |
| §5.1 User required fields | Remove `password_digest`. Add `totp_secret`, `totp_candidate_secret`, `totp_candidate_secret_expires_at`, `totp_last_used_counter`, `sessions_generation`, `enrollment_token_generation`. |
| §6.7 Authentication | Full rewrite. New flows: TOTP enrollment via email link; sign-in with email + 6-digit code; recovery via re-issued enrollment link. |
| §6.9 Rate limiting | Rename "login failures 10/IP/15min" to "sign-in code attempts"; add "5 / user / 15min". Add recovery email rate limits (3/email/hr, 5/IP/hr). |
| §7 Routes | Remove `/password-reset`, `/password-reset/:token`, `/email-verification/:token`. Add `/recover`, `/recover/:token`, `/enroll/:token`. |
| §10 Package C | Rewrite deliverables and "Done when" to match TOTP flow. Remove password-reset items. |
| §14 Testing | Replace password-reset coverage with recovery-flow coverage; replace email-verification coverage with enrollment coverage; add TOTP replay-prevention and session-invalidation tests. |

**No change required to §3 (Excluded from v1).** The enrollment/recovery email link is not a sign-in magic link — a successful click alone does not grant a session; TOTP enrollment must complete first. §3 line 65 ("Magic links" excluded) stands.

---

## 4. Architecture

### Gems added
- `rotp` — RFC 6238 TOTP validation.
- `rqrcode` — server-side QR rendering as inline SVG (no client JS required for QR).

### Gems removed
- `bcrypt` — no longer needed.

### New controllers
- **`EnrollmentsController`** — handles the landing page reached by clicking any enrollment/recovery email link. Shows QR code and accepts a confirmation code. The same `#show` and `#confirm` actions handle **both first-time enrollment and lost-device recovery**. The branching is internal to `user.begin_enrollment!` / `user.complete_enrollment!`.
- **`RecoveriesController`** — the "I lost my authenticator" request page. Accepts email, enqueues the enrollment email, responds with the generic "if an account exists…" notice.

### Repurposed or slimmed controllers
- **`SessionsController#create`** — validates email + TOTP code atomically. Adds per-user rate limit alongside the existing per-IP tracker.
- **`UsersController#create`** — creates a `User` row in `pending_enrollment` state, sends the enrollment email, does **not** start a session.

### Deleted
- `PasswordResetsController` + views + locale + mailer template.
- `EmailVerificationsController` — its URL (`/email-verification/:token`) is replaced by `/enroll/:token`.

### What does not change
- Rails signed-cookie sessions.
- `Current.user` + `Authentication` concern structure (extended, not replaced).
- Turnstile integration and service.
- `Rack::Attack`, `LoginFailureTracker`, `DisposableEmailBlocklist` (all extended).
- Pseudonym identity model, public profile shape.
- Posting / commenting / voting gates — still gate on `active?` state, which is still the gate.

---

## 5. Data Model

### Schema changes (one migration)

Remove:
- `users.password_digest`

Add:
- `users.totp_secret` — text, encrypted, nullable — current in-use secret.
- `users.totp_candidate_secret` — text, encrypted, nullable — in-progress secret during enrollment or recovery.
- `users.totp_candidate_secret_expires_at` — datetime, nullable — candidate TTL (aligned with the 30-minute token TTL).
- `users.totp_last_used_counter` — bigint, nullable — TOTP time counter of the last accepted code (replay prevention).
- `users.sessions_generation` — integer, default 0, NOT NULL — bumped on recovery completion; invalidates existing sessions.
- `users.enrollment_token_generation` — integer, default 0, NOT NULL — bumped on each enrollment/recovery email send; invalidates prior links.

### State machine

| State | Meaning |
|---|---|
| `pending_enrollment` (renamed from `pending_email_verification`) | Row exists; email and pseudonym claimed; TOTP has never been enrolled. Cannot sign in. |
| `active` | TOTP enrollment completed. Can sign in, post, comment, vote. |
| `suspended` | Moderator action. |
| `banned` | Moderator action. |

Transition: `pending_enrollment → active` on successful first-time enrollment confirmation. Recovery does **not** change state for active users — it only rotates the secret and bumps `sessions_generation`.

### User model changes

Removed: `has_secure_password`, `validates :password`, `generates_token_for :password_reset`, `password_reset_permitted?`.

Added:
- `encrypts :totp_secret`
- `encrypts :totp_candidate_secret`
- `generates_token_for :enrollment` with data block `[id, email_verified_at&.to_i || 0, enrollment_token_generation]` — any field changing invalidates the token.
- `totp` — returns an `ROTP::TOTP` bound to the in-use secret.
- `verify_totp(code)` — validates against in-use secret, enforces replay via `totp_last_used_counter`, atomic update on success.
- `begin_enrollment!` — lazy-generates `totp_candidate_secret` and sets expiry if none present or expired. Idempotent within the TTL so refreshes see the same QR. **Does not touch `totp_secret`** — so recovery is reversible mid-flow.
- `complete_enrollment!` — swaps candidate → in-use, clears candidate, transitions state if pending, sets `email_verified_at` on first-time enrollment, bumps `sessions_generation` on recovery.

### Pending-user lifecycle

Abandoned pending rows sit indefinitely, holding their `(email, pseudonym)` unique constraints. This is acceptable for v1 because:
- Turnstile on sign-up throttles mass-abandonment attacks.
- The recovery flow doubles as "resend enrollment email" for pending users.

No sweep job in v1. Add later if abuse materializes.

---

## 6. User Flows

### 6.1 Enrollment (sign-up)

1. `GET /sign-up` — form with email, pseudonym, Turnstile. No password fields.
2. `POST /sign-up` — spam check + Turnstile → create `User(state: :pending_enrollment, totp_secret: nil)` → bump `enrollment_token_generation` → enqueue enrollment email → redirect to `/sign-in` with notice *"Check your email to finish setting up your account."* **No session started.**
3. `GET /enroll/:token` — verify signed token (30-min TTL, nonce-bound). Call `user.begin_enrollment!` (idempotent). Render QR (SVG, issuer `permanentunderclass.me`, account label = email) + 6-digit code form. Render TOTP countdown element.
4. `POST /enroll/:token` — re-verify token, check rate limits, verify code against the **candidate secret**. On success: `user.complete_enrollment!` → start session → redirect home with notice.

### 6.2 Sign-in

1. `GET /sign-in` — form with email + 6-digit code + submit. Visible link: *"Can't access your authenticator? Recover access."* (Single link covers both "lost phone" and "never finished enrollment" cases.) Live TOTP countdown element.
2. `POST /sign-in` — per-IP and per-user rate limit checks. Look up user by downcased email. If `active` AND `verify_totp` succeeds: start session, redirect. If `suspended`/`banned` and email matches: show blocked message (preserves UX; minor enumeration concession). All other failures (no such email, pending user, wrong code, replay): single generic error:
   > Couldn't sign in. Your current code rotates in **Xs** — try again with the next one.

### 6.3 Recovery (lost device OR never finished enrollment)

1. `GET /recover` — form with email + Turnstile.
2. `POST /recover` — Turnstile + rate limits (3/email/hr, 5/IP/hr). If user exists AND not suspended/banned: bump `enrollment_token_generation` (invalidates prior email links) → enqueue enrollment email. **Always** redirect to `/sign-in` with identical notice regardless of whether email exists: *"If an account exists, a recovery email has been sent."*
3. `GET /enroll/:token` — exactly the same controller action as §6.1 step 3. `begin_enrollment!` writes only to `totp_candidate_secret`; the in-use `totp_secret` is untouched until commit. The old authenticator continues to work until recovery is completed.
4. `POST /enroll/:token` — exactly the same controller action as §6.1 step 4. On success for an active user: candidate → `totp_secret`, reset `totp_last_used_counter`, bump `sessions_generation` (signs out other devices). Start fresh session, redirect home.

### 6.4 Session invalidation mechanism

`sessions_generation` is bumped on recovery completion. At sign-in, the current value is stamped into the signed session cookie. On every request, `Authentication#set_current_user` compares the cookie's value against the DB value; mismatch signs the user out. ~10 lines in the concern. Kicks stale sessions on stolen-device scenarios.

### 6.5 Shared code path

§6.1 steps 3–4 and §6.3 steps 3–4 are literally the **same controller actions** with identical views and identical locale keys. The only semantic difference lives inside `begin_enrollment!` and `complete_enrollment!`, which handle the "is there an existing in-use secret?" branching internally. One page, one code path, two lifecycles.

---

## 7. Security, Rate Limiting, and Abuse Protection

### Rate limiting matrix

| Action | Per-IP | Per-user / per-email | Enforcement |
|---|---|---|---|
| Sign-in code attempts | 10 / 15 min | 5 / user / 15 min | `LoginFailureTracker` (extended with user key) |
| Enrollment code attempts | 10 / 15 min | 5 / user / 15 min | Same tracker, keyed by user id (derived from the token) |
| Recovery email requests | 5 / hr | 3 / email / hr | `Rack::Attack` |
| Sign-up submissions | 3 / hr | — | `Rack::Attack` (existing, unchanged) |

Rationale on 5/user/15min: TOTP brute force requires ~10⁶ attempts against the ±1-step window. At 5/15min, an attacker gets ~175k attempts/year per user — well below 10⁶. Per-IP limits catch distributed-but-slow attacks.

### Turnstile placement

| Surface | Widget? | Reason |
|---|---|---|
| `/sign-up` | yes | Unchanged |
| `/recover` | yes | Prevents email bombing above the 3/email/hr rate limit |
| `/sign-in` | no | Rate limits suffice; adding here would friction every sign-in |
| `/enroll/:token` | no | Token TTL + per-user rate limit suffice |

### Encryption & key management

`encrypts :totp_secret` and `encrypts :totp_candidate_secret` use Rails 8 native encryption with non-deterministic per-record IVs. Keys live in `config/credentials.yml.enc`:

```yaml
active_record_encryption:
  primary_key: <random>
  deterministic_key: <random>
  key_derivation_salt: <random>
```

No new KMS, no external key store. No new Render env vars — existing `RAILS_MASTER_KEY` decrypts the credentials.

### Token security

Enrollment tokens signed via `generates_token_for :enrollment`, 30-min TTL. Data block: `[id, email_verified_at&.to_i || 0, enrollment_token_generation]`. Any field changing invalidates the token:
- Completing enrollment bumps `email_verified_at` for the first time → invalidates in-flight enrollment emails.
- Requesting a new recovery/enrollment email bumps `enrollment_token_generation` → invalidates the previous email.

### TOTP parameters

- Algorithm: **SHA-1** (RFC 6238 default; universal authenticator-app compatibility).
- Digits: **6**.
- Step: **30 seconds**.
- Drift tolerance: **±1 step** (90-second total acceptance window).
- Replay prevention: `rotp.verify(code, after: last_counter)` rejects any code whose counter is ≤ the stored last-used counter.

### Parameter filtering (logging)

Add `code`, `totp_secret`, `totp_candidate_secret` to `config/initializers/filter_parameter_logging.rb`. Replace the existing `password` filter.

### TOTP countdown UX

Small Stimulus controller (`app/javascript/controllers/totp_countdown_controller.js`, ~20 lines) renders under the code field on `/sign-in` and `/enroll/:token`:

> Your code rotates in **14s**

Ticks down 30 → 0 → 30 each window, based on wall-clock math (`30 - Time.now.to_i % 30`). The generic sign-in error message includes a trailing reference to the same countdown:

> Couldn't sign in. Your current code rotates in **14s** — try again with the next one.

Uniform, universal, no enumeration oracle; independent of any user state.

---

## 8. Testing Strategy

### Deleted
- `test/integration/password_reset_flow_test.rb` — feature no longer exists.
- `test/integration/session_flow_test.rb` — replaced by `sign_in_flow_test.rb`.
- `test/integration/email_verification_flow_test.rb` — replaced by `enrollment_flow_test.rb`.
- Password-specific assertions in `test/models/user_test.rb` and `test/mailers/user_mailer_test.rb` (inline deletions during modification).

### Modified
- `test/fixtures/users.yml` — replace `password_digest` with pre-generated encrypted TOTP secrets so fixture users can produce valid codes deterministically.
- `test/test_helper.rb` — add `valid_totp_code_for(user)` and `sign_in_as(user)` helpers; remove any password-based helpers.
- `test/models/user_test.rb` — TOTP and state-machine coverage (replaces password tests).
- `test/integration/sign_up_flow_test.rb` — rewrite for passwordless sign-up (no session started, enrollment email sent).
- `test/mailers/user_mailer_test.rb` — drop `password_reset` tests, add `enrollment_link` tests.
- `test/controllers/authentication_guards_test.rb` — update state enum references.

### Added
- `test/integration/enrollment_flow_test.rb` — full sign-up → email → QR → code → active user; refresh idempotency; expired / tampered token.
- `test/integration/sign_in_flow_test.rb` — email + TOTP validation; replay prevention; rate limits; generic error-message parity across failure modes.
- `test/integration/recovery_flow_test.rb` — lost-phone path; `totp_secret` untouched until commit; `sessions_generation` bumps on completion; recovery works for pending users too.
- `test/controllers/enrollments_controller_test.rb` — token edge cases (expired, wrong-signature, nonce-stale, already-active, suspended, tampered).
- `test/controllers/recoveries_controller_test.rb` — generic response regardless of email existence, Turnstile enforcement, rate limits.

### Key test helpers

```ruby
def valid_totp_code_for(user)
  ROTP::TOTP.new(user.totp_secret).now
end

def sign_in_as(user)
  post sign_in_path, params: { session: { email: user.email, code: valid_totp_code_for(user) } }
end
```

**Testing gotcha:** the replay-prevention counter means re-using `sign_in_as` for the same user within 30 seconds will fail. Tests signing in multiple times per user must `travel 31.seconds` between calls or use different users. This is documented in the helper itself.

---

## 9. File Impact

Files are counted by their final-state names. Renames and replacements show up as deletes of the old name and additions of the new name.

### Added (13)

Runtime (8):
- `db/migrate/<timestamp>_replace_password_with_totp.rb`
- `app/controllers/enrollments_controller.rb`
- `app/controllers/recoveries_controller.rb`
- `app/views/enrollments/show.html.erb`
- `app/views/recoveries/new.html.erb`
- `app/views/user_mailer/enrollment_link.html.erb` (replaces `email_verification.html.erb`)
- `app/views/user_mailer/enrollment_link.text.erb` (replaces `email_verification.text.erb`)
- `app/javascript/controllers/totp_countdown_controller.js`

Tests (5):
- `test/integration/enrollment_flow_test.rb` (replaces `email_verification_flow_test.rb`, full rewrite)
- `test/integration/sign_in_flow_test.rb` (replaces `session_flow_test.rb`, full rewrite)
- `test/integration/recovery_flow_test.rb`
- `test/controllers/enrollments_controller_test.rb`
- `test/controllers/recoveries_controller_test.rb`

### Modified (~20)
- `Gemfile`, `Gemfile.lock`
- `PLAN.md` (7 sections per §3 above)
- `db/schema.rb` (regenerated)
- `app/models/user.rb`
- `app/controllers/concerns/authentication.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/users_controller.rb`
- `app/services/login_failure_tracker.rb`
- `app/views/sessions/new.html.erb`
- `app/views/users/new.html.erb`
- `app/mailers/user_mailer.rb`
- `config/routes.rb`
- `config/locales/en.yml`
- `config/initializers/filter_parameter_logging.rb`
- `config/initializers/rack_attack.rb`
- `test/fixtures/users.yml`
- `test/test_helper.rb`
- `test/models/user_test.rb`
- `test/integration/sign_up_flow_test.rb`
- `test/mailers/user_mailer_test.rb`
- `test/controllers/authentication_guards_test.rb`

### Deleted (11)

Controllers (2):
- `app/controllers/password_resets_controller.rb`
- `app/controllers/email_verifications_controller.rb`

Views (6):
- `app/views/password_resets/new.html.erb`
- `app/views/password_resets/edit.html.erb`
- `app/views/user_mailer/password_reset.html.erb`
- `app/views/user_mailer/password_reset.text.erb`
- `app/views/user_mailer/email_verification.html.erb` (replaced by `enrollment_link.html.erb`)
- `app/views/user_mailer/email_verification.text.erb` (replaced by `enrollment_link.text.erb`)

Tests (3):
- `test/integration/password_reset_flow_test.rb`
- `test/integration/session_flow_test.rb` (replaced by `sign_in_flow_test.rb`)
- `test/integration/email_verification_flow_test.rb` (replaced by `enrollment_flow_test.rb`)

`app/views/shared/_site_nav.html.erb` does not need direct edits — it already references state via `t("nav.account_states.#{current_user.state}")`, so renaming the state enum is locale-driven.

---

## 10. Prerequisites (Stop-and-Ask per CLAUDE.md)

Before the implementation migration can run anywhere, the user must:

1. Run `bin/rails db:encryption:init` locally (outputs three keys to paste).
2. Open `bin/rails credentials:edit`; add under `active_record_encryption:` the three keys from step 1.
3. Commit the updated `config/credentials.yml.enc`.
4. Confirm the existing `RAILS_MASTER_KEY` env var in Render decrypts the new credentials on next boot (no new Render env var needed).

No dashboard, DNS, billing, or other human-only actions are required beyond the above.

---

## 11. Definition of Done

- Migration applied; `password_digest` column removed; new TOTP columns present and encrypted.
- Sign-up creates pending-enrollment users, enqueues enrollment email, does not start a session.
- Clicking enrollment email → QR page → submitting correct TOTP code → user is active + signed in.
- Sign-in requires email + current TOTP code; replayed codes rejected.
- Recovery path works end-to-end; `totp_secret` untouched until commit; `sessions_generation` bumps on completion.
- Per-IP and per-user rate limits enforced on sign-in and enrollment code attempts.
- Recovery email rate limits enforced (3/email/hr, 5/IP/hr).
- Active Record encryption keys configured in credentials; `RAILS_MASTER_KEY` decrypts them.
- TOTP countdown visible on sign-in and enrollment pages; generic sign-in error references it.
- All existing test suites pass; new TOTP-specific suites pass.
- `bin/lint`, `bin/security`, `bin/test` all green.
- `PLAN.md` updated in the 7 sections listed in §3 above.
- `docs/package-c2-totp-auth-replacement.md` documents what changed, files touched, verification evidence, and follow-ups.

---

## 12. Out of Scope (Explicitly Deferred)

- Voluntary TOTP secret rotation via settings (recovery flow covers this need).
- Multiple-device management (single shared secret — users scan once per device).
- Moderator / admin credential-reset tooling (not part of v1 moderator actions).
- Backup codes (email recovery is the recovery mechanism).
- WebAuthn / passkey migration path.
- Sweep job for abandoned pending-enrollment rows.
- "Remember this device" longer-lived sessions.
