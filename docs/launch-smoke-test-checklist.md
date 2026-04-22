# Launch Smoke Test Checklist

Run this after the first production deploy and after any high-risk release.

## Platform Health

1. Open `/up` over HTTPS and confirm it returns `200`.
2. Load `/` anonymously and confirm the page renders without a server error.
3. Load a post detail page anonymously and confirm the page renders and includes cache-friendly headers.
4. Load `/about`, `/rules`, `/faq`, `/privacy`, and `/terms`.

## Authentication

1. Create a fresh account through `/sign-up`.
2. Confirm Turnstile is visible when configured.
3. Confirm the verification email is delivered.
4. Open the verification link and confirm the account becomes active.
5. Sign out and sign back in.
6. Trigger password reset and confirm the reset email is delivered.

## Core Member Flow

1. Publish one `discussion` post.
2. Publish one `build` or `shipped` post with allowed media.
3. Confirm both posts appear on the author profile.
4. Vote on a post and confirm visible counts update.
5. Add a top-level comment and a reply, then confirm thread rendering and counts update.
6. Confirm a reply alert email is sent for an allowed reply case.

## Moderation

1. File a report on a post or comment from a member account.
2. Open `/mod/reports` as a moderator.
3. Confirm the report appears in the queue and can be reviewed.
4. Request a rewrite or remove content, then confirm the visibility rules match the plan.
5. Restore the moderated item if the smoke test used production-shaped content.

## Deploy Safety

1. Confirm the Render deploy used `bin/render-release`.
2. Confirm the worker service is healthy and processing jobs.
3. Confirm uploaded media is stored in the production R2 bucket.
4. Confirm the current release can be rolled back in Render if needed.
