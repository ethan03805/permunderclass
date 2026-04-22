# Production Environment Checklist

This checklist covers the application and infrastructure values needed before the first Render deploy.

## Render Web And Worker

Set these on both `permanentunderclass-web` and `permanentunderclass-worker` unless noted otherwise.

- `RAILS_ENV=production`
- `APP_HOST=permanentunderclass.me`
- `FORCE_SSL=true`
- `RAILS_SERVE_STATIC_FILES=true`
- `ACTIVE_STORAGE_SERVICE=r2`
- `DATABASE_URL` from the `permanentunderclass-db` Render Postgres instance
- `MAILER_FROM=noreply@mail.permanentunderclass.me`
- `RAILS_LOG_LEVEL=info`
- `RAILS_MAX_THREADS=5`

## Cloudflare R2

- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET=permunderclass-media-production`

## Cloudflare Turnstile

- `TURNSTILE_SITE_KEY`
- `TURNSTILE_SECRET_KEY`

## Resend SMTP

- `SMTP_ADDRESS`
- `SMTP_PORT=587`
- `SMTP_DOMAIN=mail.permanentunderclass.me`
- `SMTP_USERNAME`
- `SMTP_PASSWORD`

## Worker-Only Values

- `JOB_CONCURRENCY=1`

## Conditional Or Future-Proof Values

- `RAILS_MASTER_KEY`
  Set this if future production config begins reading encrypted credentials. The current app is env-driven, but the blueprint keeps the slot reserved so deploys do not need a config shape change later.

## Pre-Launch Checks

- Confirm the web service uses `bin/render-release` as its pre-deploy command.
- Confirm the worker service uses `bin/worker` as its Docker command.
- Confirm the production database is PostgreSQL 16.
- Confirm the production R2 bucket and Turnstile widget are the production ones from the launch plan.
