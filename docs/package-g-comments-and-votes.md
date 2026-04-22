# Package G: Comments and Votes

## What Changed

Implemented Package G end to end across the post detail, feed, and tag surfaces.

The application now supports:
- threaded comments on post detail pages
- top-level comments plus nested replies
- sibling-group comment sorting for `top`, `new`, and `controversial`
- post voting with visible score, upvote count, and downvote count
- comment voting with the same visible counters
- vote toggling through create, opposite-vote update, and same-vote removal
- tombstone rendering for removed comments so thread shape stays intact

The post detail route now loads a real comment thread state with sort selection, per-user vote state, reply composers, and tombstone-safe rendering. Feed and tag cards also expose the post-vote controls so voting is not limited to the detail page.

## Files Added or Modified

### Queries
- `app/queries/comment_thread_query.rb` - builds sorted sibling groups for threaded comment rendering and normalizes the requested comment sort

### Controllers and Routing
- `config/routes.rb` - added nested comment creation and singular post/comment vote endpoints
- `app/controllers/application_controller.rb` - added safe internal return-path redirection support for vote mutations
- `app/controllers/posts_controller.rb` - loads comment thread state and current-user vote state on post detail
- `app/controllers/comments_controller.rb` - handles top-level comments and nested replies on post detail
- `app/controllers/post_votes_controller.rb` - handles post vote create/toggle/update behavior
- `app/controllers/comment_votes_controller.rb` - handles comment vote create/toggle/update behavior
- `app/controllers/home_controller.rb` - loads current-user post vote state for the feed
- `app/controllers/tags_controller.rb` - loads current-user post vote state for tag pages

### Views and Helpers
- `app/helpers/application_helper.rb` - added comment sort label helper
- `app/views/posts/show.html.erb` - added post vote controls, comment sort controls, comment composer, and threaded comment rendering
- `app/views/shared/_post_card.html.erb` - added post vote controls to feed and tag cards
- `app/views/shared/_vote_controls.html.erb` - shared vote UI for posts and comments
- `app/views/comments/_form.html.erb` - shared top-level and reply form partial
- `app/views/comments/_comment.html.erb` - recursive thread rendering with tombstones and reply composers

### Styles and Locales
- `app/assets/stylesheets/application.css` - added vote box, comments section, thread, nested reply, and tombstone styling
- `config/locales/en.yml` - added vote labels, comment section copy, sort labels, reply prompts, and tombstone text

### Tests
- `test/queries/comment_thread_query_test.rb` - covers default sort behavior and top/new/controversial ordering
- `test/integration/comments_and_votes_test.rb` - covers top-level comments, nested replies, tombstones, post vote transitions, and comment-vote-driven sort updates

## Verification

### Automated Checks
```bash
docker compose run --rm app bundle exec rails test test/queries/comment_thread_query_test.rb
docker compose run --rm app bundle exec rails test test/integration/comments_and_votes_test.rb
docker compose run --rm app bin/test
docker compose run --rm app bin/lint
```

Result: all commands completed successfully.

### Functional Verification
Verified through tests and code inspection that:
- replies inherit depth and respect the model-enforced nesting cap
- comment sorting works within each sibling group instead of flattening the thread
- controversial sorting prioritizes eligible comments and leaves lower-signal comments visible afterward
- post and comment votes correctly create, flip direction, and remove on same-vote repeat
- removed comments show a tombstone row while preserving nested replies underneath
- post voting is available from feed cards, tag cards, and post detail

## Follow-up Work and Limitations

- Author-side comment editing is still not exposed in the UI.
- Report controls remain pending Package I.
