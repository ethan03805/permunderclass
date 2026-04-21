# Package A: Application Bootstrap

## What Changed

Scaffolded a new Rails 8.1 application with the stack and tooling defined in `PLAN.md`. The app uses PostgreSQL, Propshaft, importmap-rails, Turbo, Stimulus, Active Storage, Solid Queue, and Solid Cache. Docker and Render deployment manifests were added, along with wrapper scripts, CI, environment configuration, and a health-check request spec.

## Files Added or Modified

### Rails Core
- `Gemfile` / `Gemfile.lock` — Rails 8.1, PostgreSQL, Propshaft, importmap, Hotwire, Solid gems
- `config/application.rb` — Solid Queue and Solid Cache configured as default adapters
- `config/database.yml` — PostgreSQL configuration for development, test, and production
- `config/storage.yml` — Active Storage backends for `test`, `local`, and env-driven `r2`
- `config/importmap.rb` — Pinning for application JavaScript dependencies
- `app/views/layouts/application.html.erb` — Propshaft asset tags, Turbo/Stimulus includes
- `app/assets/stylesheets/application.css` — Base stylesheet
- `app/javascript/application.js` — Entry point with Turbo and Stimulus imports
- `app/javascript/controllers/application.js` / `index.js` — Stimulus controller setup
- `db/migrate/*` — Active Storage, Solid Queue, and Solid Cache bootstrap migrations or migration bookkeeping
- `bin/rails`, `bin/importmap`, `bin/jobs`, `bin/dev` — Standard and custom Rails bins

### Docker & Compose
- `Dockerfile` — Single-stage Ruby 3.3 image with ffmpeg, libvips, asset precompile, and Puma boot config
- `docker-compose.yml` — Services: `app`, `worker`, `db`
- `.dockerignore`

### Render
- `render.yaml` — Blueprint for web service, worker, and PostgreSQL on Render

### CI
- `.github/workflows/ci.yml` — GitHub Actions workflow running tests, lint, and security checks

### Wrapper Scripts
- `bin/setup` — One-time project setup inside Docker
- `bin/test` — Test runner wrapper
- `bin/lint` — Linting wrapper (RuboCop, etc.)
- `bin/security` — Security audit wrapper (Brakeman, bundler-audit)
- `bin/worker` — Solid Queue worker smoke-test wrapper
- `bin/render-release` — Render release-phase command wrapper (migrations, etc.)

### Environment & Config
- `AGENTS.md` — Added documentation and top-level verification requirements for all future tasks
- `.env.example` — Template for required environment variables
- `.gitignore` — Updated for Rails, Docker, and environment files

### Health Check
- `test/integration/health_check_test.rb` — Integration test asserting `GET /up` returns 200 OK

## Verification

All verification was performed locally with Docker Compose and against the rendered manifests.

### Build and Setup
```bash
docker compose build
docker compose run --rm app bin/setup
```

### Runtime Health
```bash
docker compose up -d
curl http://localhost:3000/up
```
Response: `200 OK`

### Test Suite
```bash
docker compose run --rm app bin/test
docker compose run --rm -e CI=true app bin/test
```
Result: All tests green, including `test/integration/health_check_test.rb`, in both normal and CI-like environments.

### Lint & Security
```bash
docker compose run --rm app bin/lint
docker compose run --rm app bin/security
```
Result: No offenses or vulnerabilities reported.

### Release Script
```bash
docker compose run --rm app bin/render-release
```
Result: Migrations and boot checks completed without error.

### Worker Smoke Test
```bash
docker compose run --rm app bash -lc "bin/worker >/tmp/worker.log 2>&1 & worker_pid=\$!; sleep 2; kill -0 \$worker_pid; kill \$worker_pid; wait \$worker_pid || true"
```
Result: Solid Queue worker stayed alive long enough to confirm successful boot and queue-process startup.

### Production Boot Smoke Test
```bash
docker compose run --rm -e RAILS_ENV=production -e ACTIVE_STORAGE_SERVICE=local -e DATABASE_URL=postgresql://postgres:postgres@db:5432/permanent_underclass_development app bundle exec ruby -e 'require "./config/environment"; puts :booted'
```
Result: Production environment booted successfully with PostgreSQL and the single-database Solid Queue/Solid Cache configuration.

### Render Manifest Validation
```bash
ruby -ryaml -e 'YAML.load_file("render.yaml")'
```
Result: Parsed without errors.

### Database Schema Verification
```bash
docker compose exec db psql -U postgres -d permanent_underclass_development -c "\dt"
```
Confirmed tables for bootstrapped engines:
- `active_storage_blobs`
- `active_storage_attachments`
- `active_storage_variant_records`
- `solid_cache_entries`
- `solid_queue_jobs`
- `solid_queue_ready_executions`
- `solid_queue_claimed_executions`
- `solid_queue_blocked_executions`
- `solid_queue_failed_executions`
- `solid_queue_scheduled_executions`
- `solid_queue_recurring_executions`
- `solid_queue_semaphores`
- `solid_queue_pauses`
- `solid_queue_processes`
- `solid_queue_recurring_tasks`

### Final Service Status Check
```bash
docker compose ps
```
Result: `app`, `db`, and `worker` were all running successfully. The app service reported healthy.

## Follow-up Work and Limitations

- **Authentication**: No user model or session system yet. Required for posting, commenting, and voting in later packages.
- **Mailers**: Resend integration is not wired; Action Mailer defaults are still placeholder.
- **Cloudflare**: Turnstile and R2 buckets are not configured. DNS and proxy setup remain external.
- **Frontend**: UI copy and styling are intentionally generic. No custom design system or component library has been added.
- **Production Secrets**: `RAILS_MASTER_KEY` and database credentials must be set in Render dashboard before first deploy; they are not committed.
- **Deploy readiness dependency**: Render production deploy still depends on user-provided secrets for R2, Turnstile, SMTP, and `RAILS_MASTER_KEY`.
- **Solid Queue UI**: No monitoring dashboard (e.g., Mission Control) is installed. Operational visibility is limited to logs and SQL.
- **System tests**: Package A adds only a health-check integration test. Full browser/system coverage comes later as more user flows are added.
