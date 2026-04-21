# Package F: Submit Flow, Assets, and Hype Linter

## What Changed

Implemented Package F end to end and closed the missing post-detail prerequisite at the same time. The app now has a real `PostsController` with a canonical post detail route, a `/submit` type picker, type-specific create forms, author edit/update flows, rewrite-request recovery, a shared hype-linter service, and client-side preview/linter behavior through Stimulus.

Media handling now uses Active Storage on the post form with server-side validation for the v1 image and video rules:
- shipped posts require exactly one image
- build posts require exactly one image or one short H.264 MP4 video
- discussion posts reject media
- images are limited to JPEG/PNG/WebP and 5 MB
- videos are limited to MP4, H.264, 30 seconds, and 50 MB

The submit/edit UI includes:
- type picker at `/submit`
- type-specific fields
- tag selection from the active tag pool
- restrained style-guide guidance
- live preview
- client-side hype warnings that mirror the server-side stored linter flags

The post detail route now exists and is used by the feed/tag pages. Published and rewrite-requested posts render on their direct URL, removed posts return 404 for regular viewers, and moderators/admins can still inspect removed content.

## Files Added or Modified

### Controllers and Routing
- `config/routes.rb` — added `/submit` and resourceful post show/edit/update routes
- `app/controllers/posts_controller.rb` — create, show, edit, update, type-picker flow, author-only editing, rewrite-request recovery, and tag assignment sequencing

### Models and Services
- `app/models/post.rb` — slugged params, visibility helpers, media validation, safe media replacement/removal scheduling, and post-detail visibility rules
- `app/services/hype_linter.rb` — server-side linter mirror for hype-warning flags
- `app/services/video_metadata.rb` — ffprobe-backed video inspection for codec and duration validation

### Views and Helpers
- `app/views/posts/type_picker.html.erb` — `/submit` type picker
- `app/views/posts/new.html.erb` — create surface
- `app/views/posts/edit.html.erb` — author edit surface
- `app/views/posts/show.html.erb` — post detail surface
- `app/views/posts/_form.html.erb` — shared type-specific form with preview and linter panel
- `app/views/posts/_rewrite_banner.html.erb` — rewrite-request messaging
- `app/views/posts/_style_guide.html.erb` — submit style-guide rules
- `app/views/shared/_post_card.html.erb` — switched feed/tag cards to the real `post_path`
- `app/views/shared/_site_nav.html.erb` — added the submit link for active users
- `app/helpers/application_helper.rb` — added helper data for the form/preview/linter and submit-nav visibility

### Client-Side Behavior
- `app/javascript/controllers/post_form_controller.js` — live preview, linter warnings, tag preview, and media preview behavior

### Styles and Locales
- `app/assets/stylesheets/application.css` — submit picker, form, preview, rewrite banner, and post detail styling
- `config/locales/en.yml` — added submit/detail/style-guide/linter/build-status copy and new media validation messages

### Tests and Fixtures
- `test/test_helper.rb` — shared media upload helpers for image/video tests
- `test/services/hype_linter_test.rb` — linter rule coverage
- `test/models/post_test.rb` — media validation, visibility, and slugged route coverage
- `test/integration/submit_flow_test.rb` — type picker, form shell, and create-flow coverage for discussion/shipped/build posts
- `test/integration/post_detail_test.rb` — post detail visibility and rewrite-request recovery coverage
- `test/fixtures/posts.yml` — added slugs so fixture posts exercise the real route shape

## Verification

### Automated Checks
```bash
docker compose run --rm app bin/test
docker compose run --rm app bin/lint
docker compose run --rm app bin/security
```

Result: all three commands completed successfully.

### Functional Verification
Verified through tests and code inspection that:
- `/submit` renders a type picker first and type-specific forms after a post type is chosen
- shipped/build/discussion posts can be created through the intended UI boundary
- rewrite-requested posts can be edited by their author and return to `published` after a valid save
- hype-linter warnings are stored server-side but do not block publishing
- feed and tag pages now link to a real post detail route instead of a placeholder helper path
- removed posts return 404 for anonymous users and members, while moderators can still view them directly
- media validation enforces the configured image/video type, size, codec, and duration rules

## Follow-up Work and Limitations

- Comment threads, vote controls, and visible vote totals are still pending Package G.
- The preview is intentionally close to the saved output, but it is still a client-side approximation rather than the exact final rendered HTML.
- Archived tags are preserved on edited posts if already attached, but only active tags are selectable through the author-facing form.
