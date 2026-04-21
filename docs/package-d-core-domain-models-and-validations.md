# Package D: Core Domain Models and Validations

## What Changed

Implemented the full core domain layer for posts, comments, tags, votes, reports, and moderator actions. The schema now includes eight new tables plus a refinement migration for constraints, type-specific validations, counter-cache logic, score recomputation, slug generation, publication immutability rules, and report uniqueness enforced at both the model and database level. All user-facing validation strings are centralized in `config/locales/en.yml`.

## Files Added or Modified

### Migrations
- `db/migrate/20260421163100_create_tags.rb` — tags table with `citext` name/slug and state enum
- `db/migrate/20260421163200_create_posts.rb` — posts table with post_type, status, build_status, counters, hot_score, and media-related fields
- `db/migrate/20260421163300_create_post_tags.rb` — join table enforcing max 3 tags per post at the application layer
- `db/migrate/20260421163400_create_comments.rb` — comments table with threaded parent_id, depth, counters, and status
- `db/migrate/20260421163500_create_post_votes.rb` — post votes with unique user/post constraint
- `db/migrate/20260421163600_create_comment_votes.rb` — comment votes with unique user/comment constraint
- `db/migrate/20260421163700_create_reports.rb` — reports with partial unique index for open-report uniqueness
- `db/migrate/20260421163800_create_moderator_actions.rb` — moderator action audit trail with polymorphic target
- `db/migrate/20260421163900_refine_core_domain_models.rb` — tightened core constraints, corrected defaults, added self-referential comment foreign key, and aligned `linter_flags` storage with the plan

### Models
- `app/models/tag.rb` — case-insensitive unique name/slug, active/archived state, and automatic slug generation
- `app/models/post.rb` — type-specific validations (shipped/build/discussion), structural media rules, locked counter recounts, hot-score computation, tag limit of 3, slug generation, immutable `published_at`, `rewrite_requested_at` handling, edited-at tracking, and linter-flag normalization/shape enforcement
- `app/models/post_tag.rb` — uniqueness on [post_id, tag_id], per-post tag cap enforcement, replacement-safe tag validation, and tag-edit timestamp touching
- `app/models/comment.rb` — depth validation (0–8), automatic depth from parent, parent/post integrity, self-parent/descendant-cycle rejection, atomic reply/post counter maintenance, locked vote/report recounts, and edited-at tracking
- `app/models/post_vote.rb` — vote value inclusion (+1/-1), post counter refresh, and hot-score refresh on create/update/destroy
- `app/models/comment_vote.rb` — vote value inclusion (+1/-1) and comment counter refresh on create/update/destroy
- `app/models/report.rb` — polymorphic target, allowed target-type validation, resolver-role enforcement, automatic resolver-field clearing when reopened, open-report uniqueness, and target `report_count` refresh by recount instead of fragile increments
- `app/models/moderator_action.rb` — polymorphic target covering Post/Comment/User/Tag/Report, action-to-target compatibility rules, moderation-role enforcement, and required public/internal notes
- `app/models/user.rb` — added associations for posts, comments, reports as a target, post_votes, comment_votes, reports_as_reporter, reports_resolved, moderator actions performed, and moderator actions targeting a user

### Locales
- `config/locales/en.yml` — added model names, attribute labels, and validation error messages for all eight new models under `activerecord.errors.models.*`

### Fixtures
- `test/fixtures/users.yml` — added `moderator`, `admin`, and `another_active` users
- `test/fixtures/tags.yml` — active and archived tags
- `test/fixtures/posts.yml` — discussion, build-like, and rewrite-requested posts
- `test/fixtures/post_tags.yml` — one tagging fixture
- `test/fixtures/comments.yml` — top-level and reply comments
- `test/fixtures/post_votes.yml` — one post vote fixture
- `test/fixtures/comment_votes.yml` — one comment vote fixture
- `test/fixtures/reports.yml` — open and resolved report fixtures
- `test/fixtures/moderator_actions.yml` — one moderator action fixture

### Tests
- `test/models/tag_test.rb`
- `test/models/post_test.rb`
- `test/models/post_tag_test.rb`
- `test/models/comment_test.rb`
- `test/models/post_vote_test.rb`
- `test/models/comment_vote_test.rb`
- `test/models/report_test.rb`
- `test/models/moderator_action_test.rb`

All tests cover validation rules, enum behavior, counter-cache logic, uniqueness constraints, and callback side effects.

## Verification

### Automated Checks
```bash
docker compose run --rm app bin/setup
docker compose run --rm app bin/test
docker compose run --rm app bin/lint
docker compose run --rm app bin/security
```
Result: all commands completed successfully with 0 failures, 0 errors, 0 lint offenses, and 0 security warnings.

### Schema Verification
Verified through migration output and `db/schema.rb` review that:
- all eight tables exist with correct columns, defaults, and indexes
- partial unique index on `reports` enforces open-report uniqueness at the database level
- foreign keys are present where specified

### Model Constraint Verification
Verified through test coverage that:
- shipped posts require `link_url` and an image attachment
- build posts require `build_status` and exactly one image or video
- discussion posts reject media attachments without inventing an extra `link_url` prohibition not present in `PLAN.md`
- tag count cannot exceed 3
- replacing one of three existing tags remains valid while concurrent direct inserts are serialized through a post lock
- comment depth is capped at 8, is auto-computed from parent, and replies must stay on the same post
- comments cannot point to themselves or one of their descendants as a parent
- comment create/destroy updates both parent `reply_count` and post `comment_count`
- `published_at` is stamped on create and cannot be changed later through normal model updates
- vote create/update/destroy correctly recalculates cached counters and post hot score using the new score value
- report open/resolved/dismissed/reopened transitions maintain target `report_count`, support `User` targets, and require a moderator/admin resolver when closed
- resolved/dismissed reports require `resolved_by_id` and `resolved_at`
- moderator actions require notes, a moderator/admin actor, and a valid target for each action type

## Follow-up Work and Limitations

- Media attachment validations enforce structural presence/absence but do not yet validate file type, size, H.264 codec, or video duration. Exact media validation belongs to Package F.
- `hot_score` is recomputed on every vote mutation but the recurring background refresh job for posts from the last 14 days belongs to Package E.
- Feed visibility rules (published vs rewrite_requested vs removed) are defined in the schema but feed queries and controllers belong to Package E.
- Comment tombstone rendering, post detail views, submit flows, moderation UI, and profile pages are explicitly out of scope for Package D and belong to later packages.
