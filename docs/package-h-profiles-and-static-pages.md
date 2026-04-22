# Package H: Profiles and Static Pages

## What Changed

Package H adds the public profile route at `/u/:pseudonym` and the five required static pages at `/about`, `/rules`, `/faq`, `/privacy`, and `/terms`.

Profiles stay deliberately minimal. Each profile now exposes:

- a post history view ordered newest-first
- a post-type filter for `shipped`, `build`, and `discussion`
- a comment history view linked back into the relevant post thread

Profile visibility follows the current read-path rules:

- published posts appear publicly
- `rewrite_requested` posts remain visible on the author profile
- removed posts stay hidden from regular viewers and remain visible to moderators and admins

Static pages render from `config/locales/en.yml` so the app keeps all user-facing copy in the locale registry. The footer now links to those pages, and pseudonyms across the app link through to profile pages.

## Files Added Or Modified

- `app/controllers/users_controller.rb`
- `app/controllers/static_pages_controller.rb`
- `app/views/users/show.html.erb`
- `app/views/users/_post.html.erb`
- `app/views/users/_comment.html.erb`
- `app/views/static_pages/show.html.erb`
- `app/views/shared/_site_nav.html.erb`
- `app/views/shared/_footer.html.erb`
- `app/views/shared/_post_card.html.erb`
- `app/views/posts/show.html.erb`
- `app/views/comments/_comment.html.erb`
- `app/views/posts/_form.html.erb`
- `app/assets/stylesheets/application.css`
- `config/locales/en.yml`
- `config/routes.rb`
- `test/integration/profile_pages_test.rb`

## Verification

Planned verification for this package:

- `bin/test`
- `bin/lint`
- `bin/security`

During implementation I also added targeted integration coverage for:

- public profile visibility
- post-type filtering
- comment history rendering
- moderator visibility of removed profile posts
- locale-backed static page rendering

## Follow-Up Work Or Known Limitations

- The static page copy is intentionally generic placeholder content, consistent with the plan’s instruction to stop before expanding legal copy beyond placeholders.
- Profile pages stay minimal and do not yet expose moderation/report controls; those belong to Package I.
