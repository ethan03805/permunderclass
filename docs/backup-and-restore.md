# Backup And Restore Notes

These notes assume the production database runs on Render Postgres and media files live in Cloudflare R2.

## Primary Recovery Path

Use Render Postgres point-in-time recovery first when production data needs to be recovered.

- Recover to a new database instance instead of overwriting the current primary in place.
- Validate the recovered database before repointing the web and worker services.
- Treat the original database as the rollback option until the recovered instance is confirmed.

## Logical Exports

Use a logical export when a portable backup file is needed for local inspection or for restoring to another Postgres instance.

- Trigger the export from the database Recovery page in Render.
- Store the downloaded `.dir.tar.gz` export in the team’s chosen secure storage location.
- Do not restore an export into a database that contains important data in the same schema.

## Restore Drill

Run a restore drill before launch and after any major schema change.

1. Trigger a new logical export from the production-shaped database.
2. Restore that export into a disposable Postgres instance.
3. Run `bin/test` locally against the restored schema if application-level validation is needed.
4. Verify key tables such as `users`, `posts`, `comments`, `reports`, `post_votes`, and `comment_votes`.
5. Verify Active Storage blob rows exist for uploaded media records.
6. Delete the disposable restore target after validation.

## Media Recovery

Render Postgres recovery does not restore Cloudflare R2 objects.

- Keep the production bucket name stable.
- Avoid manual object deletions unless the related moderation action requires it.
- If object recovery is ever needed, restore from the bucket’s own retention or backup process rather than the database workflow.

## Ownership And Limits

- Render point-in-time recovery availability depends on the paid database plan.
- Triggering recovery instances and exports is a user-owned dashboard action.
- If a real incident occurs, record the recovery time, database name, operator, and post-incident follow-up in the deployment log.
