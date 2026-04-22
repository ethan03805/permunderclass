# Package K: Deployment, CI, and Launch Hardening

## What Changed

Package K finishes the delivery surface around the existing Rails application.

- GitHub Actions now runs the repository wrapper commands with a production-shaped dependency set, including `ffmpeg` so media validation executes in CI instead of skipping.
- The Render blueprint now waits for CI checks before auto-deploying, runs `bin/render-release` before web deploys, and declares the mailer and runtime environment values needed by both services.
- Production mail delivery now reads SMTP settings from environment variables so verification, reset, and reply-alert mailers can work after deployment.
- Deployment runbooks now exist for production environment setup, backup and restore handling, and launch smoke testing.

## Files Added Or Modified

- `.github/workflows/ci.yml`
- `.env.example`
- `app/mailers/application_mailer.rb`
- `bin/render-release`
- `config/environments/production.rb`
- `render.yaml`
- `docs/production-environment-checklist.md`
- `docs/backup-and-restore.md`
- `docs/launch-smoke-test-checklist.md`

## Verification

Verified with:

- `docker compose run --rm app env PARALLEL_WORKERS=1 bin/test`
- `docker compose run --rm app bin/lint`
- `docker compose run --rm app bin/security`

Observed verification results:

- `bin/test`: 241 runs, 850 assertions, 0 failures, 0 errors, 0 skips
- `bin/lint`: 114 files inspected, 0 offenses
- `bin/security`: 0 Brakeman warnings, 0 bundled gem vulnerabilities

## Follow-Up Work Or Known Limitations

- Render Blueprint sync, domain attachment, secret entry, and any paid-plan changes remain user-owned actions.
- Render Postgres point-in-time recovery depends on a paid Render Postgres plan.
