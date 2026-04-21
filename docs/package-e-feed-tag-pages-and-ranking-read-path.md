# Package E: Feed, Tag Pages, and Ranking Read Path

## What Changed

Implemented the read-path surfaces for posts: the home feed, tag detail pages, and the supporting ranking and query infrastructure. The feed is URL-driven, supporting sort tabs (hot/new/top), a top-ranking time window, multi-select post-type filters, and single-tag filtering. Posts are rendered through a shared card partial with 25-post manual pagination. Hot-score computation was extracted into a dedicated service (`PostRanking`), and a recurring background job refreshes hot scores for posts from the last 14 days. Only published posts appear in listings.

## Files Added or Modified

### Services and Queries
- `app/services/post_ranking.rb` — extracted hot-score formula; computes score from vote count, age decay, and a gravity constant
- `app/queries/feed_query.rb` — composable query object enforcing `published` scope, sort strategy, time window, post-type filter, and tag filter

### Jobs
- `app/jobs/refresh_hot_scores_job.rb` — recurring job that refreshes `hot_score` for posts published within the last 14 days

### Controllers
- `app/controllers/tags_controller.rb` — `show` action loading a tag and its filtered, paginated feed
- `app/controllers/home_controller.rb` — modified to use `FeedQuery` for sort, filter, window, and pagination params; now sets feed metadata for the view

### Views
- `app/views/tags/show.html.erb` — tag page shell reusing the shared feed partials and filters
- `app/views/home/index.html.erb` — modified to render feed filters, post cards, and pagination
- `app/views/shared/_post_card.html.erb` — shared post card with title, metadata, score, type badge, and tag list
- `app/views/shared/_feed_filters.html.erb` — sort tabs (hot/new/top), top-window dropdown, type checkboxes, and tag link handling
- `app/views/shared/_pagination.html.erb` — simple prev/next manual pagination for 25-post pages

### Models
- `app/models/post.rb` — modified to delegate hot-score computation to `PostRanking` and expose scopes used by `FeedQuery`

### Helpers
- `app/helpers/application_helper.rb` — added feed-state helpers and a post-permalink placeholder pending the real post detail route

### Routes
- `config/routes.rb` — added the `/tags/:slug` route; feed filter state is carried by query params on root

### Locales
- `config/locales/en.yml` — added feed, sort, filter, pagination, and tag page strings

### Recurring Jobs Config
- `config/recurring.yml` — registered `RefreshHotScoresJob` on its scheduled interval

### Styles
- `app/assets/stylesheets/application.css` — added restrained feed, card, filter, and pagination styles

### Tests
- `test/services/post_ranking_test.rb` — coverage for score computation, age decay, and tie-breaking
- `test/queries/feed_query_test.rb` — coverage for each filter/sort combination and published-only enforcement
- `test/jobs/refresh_hot_scores_job_test.rb` — coverage for job scope and idempotency
- `test/integration/feed_test.rb` — end-to-end coverage for sort tabs, filters, pagination, and URL state round-trips
- `test/integration/tag_page_test.rb` — end-to-end coverage for tag show page, filtered feed, and empty state
- `test/integration/home_page_test.rb` — updated to assert feed rendering and filter behavior on the root path
- `test/models/post_test.rb` — updated to cover `PostRanking` delegation and feed scopes

## Verification

### Automated Checks
```bash
docker compose run --rm app bin/test
docker compose run --rm app bin/lint
docker compose run --rm app bin/security
```
Result: all commands completed successfully with 0 failures, 0 errors, 0 lint offenses, and 0 security warnings.

### Functional Verification
Verified through integration tests and source inspection that:
- feed state is URL-driven: sort, window, type, and tag parameters serialize into and restore from query strings
- sort tabs hot/new/top switch the ordering strategy correctly
- top-window dropdown (day/week/month/all) is available only under top sort and applies the expected time range
- type multi-filter allows selecting one or more of discussion/shipped/build
- single-tag filter links from posts and tag pages constrain the feed to that tag
- tag route (`/tags/:slug`) renders the tag name and a scoped feed
- shared `_post_card` partial is used by both home and tag pages
- only `published` posts appear in listings; `rewrite_requested` and `removed` posts are excluded
- pagination surfaces 25 posts per page with working prev/next navigation
- `RefreshHotScoresJob` runs on schedule and updates hot scores for posts from the last 14 days
- `PostRanking` encapsulates the hot formula and is invoked by the model on vote changes and by the refresh job

## Follow-up Work and Limitations

- Post detail route and view are not yet implemented; clicking a post title currently relies on a helper-based permalink placeholder that should be replaced by a real `post_path` in the post-detail package (likely Package G).
- No caching layer is in place yet for anonymous feed or tag pages; caching belongs to a later performance pass.
- Submit flow, comment threads, voting interactions, moderation UI, and profile pages remain out of scope and will be delivered by later packages.
