# permanentunderclass.me

Rails 8 application for permanentunderclass.me.

## Local development

This repository is designed to run through Docker for local development.

### Start the stack

```bash
docker compose build
docker compose run --rm app bin/setup
docker compose up
```

### Useful commands

```bash
docker compose run --rm app bin/test
docker compose run --rm app bin/lint
docker compose run --rm app bin/security
docker compose run --rm app bin/worker
```

### Health check

```bash
curl http://localhost:3000/up
```

## Source of truth

Read `PLAN.md` before making product or architecture changes.
