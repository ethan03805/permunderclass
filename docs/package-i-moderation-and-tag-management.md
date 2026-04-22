# Package I: Moderation and Tag Management

## What Changed

Package I adds the first complete moderation surface for the application.

Community reporting now works through a shared report form for:

- posts
- comments
- user profiles

Moderators and admins now have a dedicated moderation namespace with:

- `/mod/reports` for the open reports queue
- report review pages for processing individual reports
- `/mod/users/:id` for account review and suspension/ban actions
- `/mod/tags` for creating, renaming, merging, and archiving tags

Moderation controls were also added directly to the existing post and comment surfaces so moderators can:

- request rewrites
- remove posts
- restore posts
- remove comments

Every moderation mutation now writes a `ModeratorAction` audit entry.

## Files Added Or Modified

- `app/controllers/concerns/authentication.rb`
- `app/controllers/reports_controller.rb`
- `app/controllers/mod/base_controller.rb`
- `app/controllers/mod/reports_controller.rb`
- `app/controllers/mod/posts_controller.rb`
- `app/controllers/mod/comments_controller.rb`
- `app/controllers/mod/users_controller.rb`
- `app/controllers/mod/tags_controller.rb`
- `app/helpers/application_helper.rb`
- `app/views/reports/_form.html.erb`
- `app/views/mod/shared/_action_log.html.erb`
- `app/views/mod/reports/index.html.erb`
- `app/views/mod/reports/show.html.erb`
- `app/views/mod/users/show.html.erb`
- `app/views/mod/tags/index.html.erb`
- `app/views/posts/show.html.erb`
- `app/views/comments/_comment.html.erb`
- `app/views/users/show.html.erb`
- `app/views/shared/_site_nav.html.erb`
- `app/assets/stylesheets/application.css`
- `config/locales/en.yml`
- `config/routes.rb`
- `test/integration/moderation_and_reporting_test.rb`

## Verification

Planned package verification:

- `bin/test`
- `bin/lint`
- `bin/security`

Targeted coverage added in this package exercises:

- public post reporting
- moderator-only route protection
- report queue rewrite handling
- post restoration
- comment removal with tombstone rendering
- account suspension
- tag create/rename/merge/archive flows

## Follow-Up Work Or Known Limitations

- The moderation UI is intentionally minimal and text-first; it focuses on the required v1 actions rather than richer workflow features like filtering, bulk actions, or saved moderator notes.
- User restoration is still not exposed because the current moderation action model only specifies suspension and ban actions in v1.
