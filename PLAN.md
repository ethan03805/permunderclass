# permanentunderclass.me

Status: locked implementation plan
Change control: do not modify this file during routine implementation. Only modify it when the user explicitly approves a plan change.
Purpose: this file is the product, architecture, delivery, and execution source of truth for the repository.

## 1. Product Definition

permanentunderclass.me is a pseudonymous community site for indie, solo, and bootstrapped builders to post what they are making.

The product is structurally closest to Reddit plus Product Hunt:
1. Posts
2. Upvotes and downvotes
3. Threaded comments
4. A default hot feed
5. Time-window top rankings
6. Topic tags
7. Minimal profiles

The differentiator is not gamification or launch theatrics. The differentiator is tone and identity:
1. Anti-hustle
2. Dry and restrained
3. Pseudonymous by default
4. Status games minimized
5. No monetization in v1
6. No dark patterns

For now, UI copy stays generic and functional. Do not add jokes, slogans, or voice-heavy copy until the user provides a formal voice document.

## 2. Non-Negotiables

These are fixed:
1. Ruby on Rails is the application stack.
2. Email and password authentication is required in v1.
3. Browsing is anonymous.
4. Posting, voting, and commenting require an account.
5. Public identity is a pseudonym. Real names and phone numbers are never required.
6. Build posts may include a short `mp4` H.264 video up to 30 seconds and 50 MB. No transcoding in v1.
7. Cloudflare is approved for DNS, proxying, Turnstile, and R2.
8. Reply alerts are email-only in v1.
9. A `rewrite_requested` post remains visible on its direct URL and on the author profile, but is removed from feed and tag listings until edited.
10. No third-party tracking scripts in v1.
11. No monetization features in v1.
12. No badges, awards, karma leaderboards, or follower mechanics in v1.
13. No direct messages in v1.
14. No full-text search in v1.
15. No native app in v1.
16. No separate mobile product in v1. The site is responsive web only.

## 3. Explicitly Excluded From v1

Do not add any of the following without explicit user approval:
1. DMs
2. Chat
3. Dedicated rankings or leaderboard pages beyond feed sort tabs
4. Full-text search
5. In-app notification center
6. Push notifications
7. Native mobile apps
8. User badges, awards, achievements, streaks, karma scores, or top-user leaderboards
9. Paid listings, sponsored slots, ads, premium tiers, or job board features
10. User blocking beyond report and moderator review
11. Karma-gated posting or voting
12. Social login
13. Magic links
14. Passkeys
15. Public APIs for third-party clients
16. Theme marketplace or UI kit integration
17. Any analytics product that requires a client-side tracking script

## 4. Fixed Technical Decisions

### 4.1 Application Stack

1. Ruby `3.3`
2. Rails `8`
3. PostgreSQL `16`
4. Puma as the app server
5. ERB + Hotwire (`Turbo` + `Stimulus`)
6. Plain CSS with CSS variables for design tokens
7. Propshaft and importmap; avoid introducing a Node-based frontend toolchain in v1
8. Active Storage for uploads
9. Cloudflare R2 for object storage
10. Cloudflare Turnstile for abuse protection
11. Rails signed-cookie sessions
12. `has_secure_password` for password authentication
13. `Rack::Attack` for application-level throttling
14. `Solid Queue` for background jobs
15. `Solid Cache` for application cache and throttle backing store
16. GitHub Actions for CI
17. Render for hosting:
   1. one web service
   2. one worker service
   3. one managed Postgres instance
18. Resend via SMTP for transactional email
19. Cloudflare proxy and caching in front of the site
20. Server-side request logs and database rollups for analytics

### 4.2 UI Constraints

1. Base face is system sans.
2. Monospace is accent-only:
   1. timestamps
   2. rank numbers
   3. minor labels if needed
3. Use cream or off-white background and near-black text by default.
4. Use underlined links in a single accent color.
5. Use borders, spacing, and type hierarchy instead of cards and decoration.
6. No shadows.
7. No gradients.
8. No decorative icons unless functionally necessary.
9. No component libraries.
10. All user-facing strings live in `config/locales/en.yml` from the start, even though the app is English-only.

### 4.3 Repository Contract

The implementation must create and maintain these wrapper commands early so agents stop inventing ad hoc commands:
1. `bin/setup`
2. `bin/dev`
3. `bin/test`
4. `bin/lint`
5. `bin/security`
6. `bin/worker`
7. `bin/render-release`

Once present, these wrappers become the default command surface for agents.

## 5. Core Data Model

### 5.1 Users

Public identity is a pseudonym.

Required fields:
1. `pseudonym`
2. `email`
3. `password_digest`
4. `role`
5. `state`
6. `email_verified_at`
7. `reply_alerts_enabled`

Rules:
1. `pseudonym` is case-insensitive unique.
2. `pseudonym` is 3 to 30 characters.
3. Allowed pseudonym characters are letters, numbers, and underscore.
4. `email` is case-insensitive unique.
5. `role` enum:
   1. `member`
   2. `moderator`
   3. `admin`
6. `state` enum:
   1. `pending_email_verification`
   2. `active`
   3. `suspended`
   4. `banned`
7. No avatar uploads in v1.
8. No follower counts.
9. No karma totals.
10. No profile badges.

### 5.2 Tags

Tags are from a moderated pool. Users select from existing tags only.

Required fields:
1. `name`
2. `slug`
3. `state`

Rules:
1. `state` enum:
   1. `active`
   2. `archived`
2. Tags are created, renamed, merged, and archived by moderators or admins only.
3. A post may have 0 to 3 tags.
4. No user-created freeform tags in v1.

### 5.3 Posts

Single-table content model with type-specific validation.

Required fields:
1. `user_id`
2. `post_type`
3. `title`
4. `body`
5. `status`
6. `published_at`
7. `upvote_count`
8. `downvote_count`
9. `score`
10. `comment_count`
11. `hot_score`
12. `report_count`
13. `linter_flags`

Optional fields:
1. `slug`
2. `link_url`
3. `build_status`
4. `rewrite_requested_at`
5. `rewrite_reason`
6. `edited_at`

Enums:
1. `post_type`
   1. `shipped`
   2. `build`
   3. `discussion`
2. `status`
   1. `published`
   2. `rewrite_requested`
   3. `removed`

Type rules:
1. `shipped`
   1. requires `title`
   2. requires `link_url`
   3. requires `body`
   4. requires exactly 1 image attachment
   5. does not allow video attachment
2. `build`
   1. requires `title`
   2. requires `body`
   3. requires `build_status`
   4. requires exactly 1 image or exactly 1 short video
   5. `link_url` is optional
3. `discussion`
   1. requires `title`
   2. requires `body`
   3. does not require `link_url`
   4. does not allow media attachments

Build status enum:
1. `sharing`
2. `want_feedback`
3. `looking_for_testers`

General post rules:
1. `title` max length is 140.
2. `body` max length is 10_000.
3. `link_url` must be `http` or `https`.
4. `published_at` is set on first successful publish and is never reset by edits.
5. `edited_at` updates on author or moderator edits.
6. `linter_flags` stores soft hype-linter findings for transparency and moderation context.
7. `score = upvote_count - downvote_count`.

### 5.4 Media Attachments

Use Active Storage for all media.

Rules:
1. Allowed image types:
   1. `image/jpeg`
   2. `image/png`
   3. `image/webp`
2. Max image size is 5 MB.
3. Allowed video type is `video/mp4`.
4. Video codec must be H.264.
5. Max video length is 30 seconds.
6. Max video size is 50 MB.
7. No video transcoding in v1.
8. No GIF uploads in v1.
9. No avatars in v1.

### 5.5 Comments

Comments are threaded and voteable.

Required fields:
1. `post_id`
2. `user_id`
3. `parent_id`
4. `depth`
5. `body`
6. `status`
7. `upvote_count`
8. `downvote_count`
9. `score`
10. `reply_count`
11. `report_count`
12. `edited_at`

Enums:
1. `status`
   1. `published`
   2. `removed`

Rules:
1. Hard maximum nesting depth is 8.
2. UI indentation cap is 8.
3. `body` max length is 5_000.
4. `score = upvote_count - downvote_count`.
5. Removed comments preserve thread shape and display a tombstone row instead of disappearing entirely.
6. Comment authors may edit their own comments.
7. Comment authors may not hard-delete comments in v1.
8. Moderators may remove comments.

### 5.6 Votes

Votes are stored separately for posts and comments.

Tables:
1. `post_votes`
2. `comment_votes`

Required fields:
1. `user_id`
2. target foreign key
3. `value`

Rules:
1. `value` must be `1` or `-1`.
2. One row per user per target.
3. Changing a vote updates cached counters on the target.
4. Deleting a vote is allowed and recalculates cached counters.
5. Vote counts are public on both posts and comments.

### 5.7 Reports

Reports are how the community flags hype, spam, abuse, and other issues.

Required fields:
1. `reporter_id`
2. `target_type`
3. `target_id`
4. `reason_code`
5. `details`
6. `status`
7. `resolved_by_id`
8. `resolved_at`

Enums:
1. `target_type`
   1. `Post`
   2. `Comment`
   3. `User`
2. `reason_code`
   1. `spam`
   2. `hype`
   3. `abuse`
   4. `off_topic`
   5. `other`
3. `status`
   1. `open`
   2. `resolved`
   3. `dismissed`

Rules:
1. Duplicate open reports by the same user on the same target are not allowed.
2. `details` is optional.
3. Open report count is denormalized to the target where useful.

### 5.8 Moderator Actions

Every moderator action must have an audit trail.

Required fields:
1. `moderator_id`
2. `target_type`
3. `target_id`
4. `action_type`
5. `public_note`
6. `internal_note`
7. `metadata`

Action types:
1. `rewrite_requested`
2. `restored`
3. `removed`
4. `comment_removed`
5. `user_suspended`
6. `user_banned`
7. `tag_created`
8. `tag_renamed`
9. `tag_merged`
10. `tag_archived`
11. `report_dismissed`

## 6. Core Behavior Rules

### 6.1 Feed

Home feed route: `/`

Supported sorts:
1. `hot` default
2. `new`
3. `top`

Top windows:
1. `day`
2. `week`
3. `month`
4. `all`

Supported filters:
1. post type multi-select:
   1. `shipped`
   2. `build`
   3. `discussion`
2. single-tag filter in v1

Feed query params:
1. `sort`
2. `window`
3. `types`
4. `tag`
5. `page`

Pagination:
1. 25 posts per page

Visibility:
1. `published` posts appear in feed and tag listings.
2. `rewrite_requested` posts do not appear in feed or tag listings.
3. `removed` posts do not appear in feed or tag listings.

Hot ranking uses classic Reddit-style hot ranking:

```text
order = log10(max(abs(score), 1))
sign = 1 if score > 0, -1 if score < 0, 0 otherwise
seconds = published_at.to_i - 1134028003
hot_score = round(sign * order + seconds / 64800.0, 7)
```

Additional feed rules:
1. `hot` only considers posts with `published_at >= 14 days ago`.
2. `new` sorts by `published_at desc`.
3. `top` sorts by `score desc`, then `upvote_count desc`, then `published_at desc`.
4. Recompute `hot_score` on every vote mutation.
5. Run a recurring background job every 15 minutes to refresh `hot_score` for posts from the last 14 days.

### 6.2 Post Detail

Post detail route: `/posts/:id-:slug`

Visibility:
1. `published` is public.
2. `rewrite_requested` is public on direct URL.
3. `removed` returns 404 for anonymous users and regular members.
4. `removed` is still visible to moderators and admins.
5. The author may still access their own `rewrite_requested` post.

Displayed content:
1. post content
2. visible vote counts
3. threaded comments
4. comment composer for signed-in active users
5. report controls
6. rewrite banner if applicable

### 6.3 Comments

Comment sorts:
1. `top`
2. `new`
3. `controversial`

Rules:
1. Sorting applies within each sibling group.
2. `top` uses `score desc`.
3. `new` uses `created_at desc`.
4. `controversial` uses:
   1. only comments with at least 4 total votes are eligible
   2. order by `(upvote_count + downvote_count) / GREATEST(ABS(score), 1)` desc
   3. tie-break on newer first

### 6.4 Profiles

Profile route: `/u/:pseudonym`

Profile shows only:
1. pseudonym
2. join date
3. post history
4. comment history

Rules:
1. no public email
2. no follower count
3. no karma total
4. no achievements
5. post history can be filtered by post type
6. removed posts are not shown publicly
7. rewrite-requested posts remain visible on the author profile

### 6.5 Submit Flow

Submit route: `/submit`

Flow:
1. pick post type first
2. render type-specific form fields
3. show inline style guide
4. show preview
5. show soft hype-linter warnings
6. publish if validations pass

Hype-linter:
1. client-side only for the warning UI
2. the server mirrors the checks and stores warning flags for moderator context
3. it never blocks publish on its own

Initial linter patterns:
1. repeated emoji sequences
2. `revolutionize`
3. `game changer`
4. `game-changer`
5. `disrupt`
6. `10x`
7. `unicorn`
8. `world-class`
9. `best-in-class`
10. `groundbreaking`
11. `next-gen`
12. `seamless`
13. all-caps word runs of 4 or more letters
14. multiple exclamation marks
15. exaggerated urgency phrases

The submit page style guide must tell users to:
1. say what it is
2. say what state it is in
3. say who it is for
4. avoid slogans
5. avoid fundraising language
6. avoid launch-day hype framing

### 6.6 Moderation

Minimum v1 moderator tooling:
1. reports queue
2. content review screen
3. user review screen
4. tag management
5. moderator action log

Moderator actions:
1. request rewrite
2. remove post
3. restore post
4. remove comment
5. dismiss report
6. suspend user
7. ban user
8. create tag
9. rename tag
10. merge tags
11. archive tag

Rewrite-requested behavior:
1. post status changes to `rewrite_requested`
2. post leaves the home feed
3. post leaves tag pages
4. post remains accessible on its direct URL
5. post remains visible on the author profile
6. the author can edit the post
7. saving a valid edit returns the post to `published`
8. hot ranking age stays tied to original `published_at`
9. the moderator must leave a public note

### 6.7 Authentication

V1 auth includes:
1. sign up
2. sign in
3. sign out
4. email verification
5. password reset
6. session management

Rules:
1. email verification is required before posting, commenting, or voting
2. unverified users can sign in and browse
3. no social login
4. no magic links
5. no passkeys
6. no phone verification
7. no mandatory real-name fields

### 6.8 Reply Alerts

Email-only in v1.

Send email for:
1. direct replies to a user's comment
2. new comments on a user's post, excluding the author's own comments

Rules:
1. one boolean preference controls all reply emails
2. default is enabled
3. no in-app notification center
4. no unread badge
5. no digest emails in v1

### 6.9 Rate Limiting and Spam

Use layered protection.

Application-level limits:
1. sign up:
   1. 3 per IP per hour
2. login failures:
   1. 10 per IP per 15 minutes
3. post creation:
   1. 2 per user per 24 hours
   2. 1 per user per 10 minutes
4. comment creation:
   1. 6 per user per minute
   2. 60 per user per hour
5. vote mutations:
   1. 30 per user per minute
   2. 500 per user per day

Fresh-account limits for the first 24 hours after email verification:
1. 1 post per day
2. 20 comments per day
3. 100 vote mutations per day

Spam mitigation layers:
1. Turnstile on sign up
2. Turnstile on first post from a new account
3. Turnstile on suspicious submit patterns
4. honeypot field on sign up and submit
5. minimum submit time heuristic on sign up and submit
6. disposable email domain blocklist
7. email verification before interaction
8. community report queue for live moderation
9. no public trust score
10. no shadowban system in v1

### 6.10 Privacy and Analytics

Rules:
1. no Google Analytics
2. no Meta pixel
3. no third-party client tracking scripts
4. analytics comes from server request logs, Render metrics, and database rollups only
5. the privacy page must state this plainly before launch

## 7. Routes and Pages

Required v1 routes:
1. `/`
2. `/posts/:id-:slug`
3. `/submit`
4. `/u/:pseudonym`
5. `/tags/:slug`
6. `/about`
7. `/rules`
8. `/faq`
9. `/privacy`
10. `/terms`
11. `/sign-in`
12. `/sign-up`
13. `/password-reset`
14. `/password-reset/:token`
15. `/email-verification/:token`
16. `/mod/reports`
17. `/mod/tags`
18. `/mod/users/:id`
19. `/up`

## 8. Build Order

Build in this order. Do not skip ahead unless the dependency chain explicitly allows it.

1. Repository bootstrap and command wrappers
2. Application shell, layout, tokens, and string centralization
3. Authentication and account state
4. Core models and migrations
5. Public feed and post detail
6. Submit flows and media validation
7. Comments, voting, and ranking
8. Profiles and static pages
9. Moderation and reporting
10. Reply email alerts
11. Hardening:
   1. rate limiting
   2. spam protection
   3. edge caching
   4. privacy page
12. Deployment and launch checklist

## 9. Orchestrator Execution Protocol

This repository is expected to be developed mainly by AI agents coordinated in orchestrator mode. Work must therefore be package-oriented, dependency-aware, and verifiable.

Rules:
1. Agents must work from package boundaries, not vague broad goals.
2. A package may be split among multiple agents only when the split follows clear file or surface boundaries.
3. Parallel work is allowed only when package dependencies explicitly allow it.
4. Each package must end with:
   1. implemented code
   2. updated tests
   3. verification using repo wrapper commands when available
   4. a short note of any follow-on work required
5. If a package requires a dashboard action, billing action, DNS change, credential, or other user-owned action, the agent must stop and return exact instructions instead of guessing or stubbing silently.
6. Agents must not widen scope to absorb later packages for convenience.
7. If package outputs conflict with this plan, the plan wins and the agent must stop and ask the user.

## 10. AI Work Packages

These packages are structured for orchestrator mode. Each package has a clean boundary, explicit outputs, and a stop condition for user-owned actions.

### Package A: Bootstrap and Repo Contract

Depends on:
1. nothing

Outputs:
1. Rails app scaffold
2. Postgres configured
3. wrapper commands:
   1. `bin/setup`
   2. `bin/dev`
   3. `bin/test`
   4. `bin/lint`
   5. `bin/security`
   6. `bin/worker`
   7. `bin/render-release`
4. Dockerfile for deployment
5. `render.yaml`
6. base CI workflow
7. `/up` health endpoint

Done when:
1. the app boots locally
2. `bin/test` runs
3. `bin/lint` runs
4. `bin/security` runs
5. `render.yaml` exists
6. the health check returns 200

Stop and ask user if:
1. any vendor account or secret is required

### Package B: Layout, Tokens, and Copy Registry

Depends on:
1. Package A

Can run in parallel with:
1. Package C after the app shell exists

Outputs:
1. base layout
2. shared header, footer, and nav
3. responsive shell
4. tokenized CSS variables
5. locale file structure for all UI strings
6. generic placeholder copy only

Done when:
1. all layouts render on desktop and mobile widths
2. all visible strings come from locale files
3. no cards, shadows, or gradients appear
4. links are underlined
5. spacing and type hierarchy carry the layout

Stop and ask user if:
1. the visual direction needs to change beyond the brief

### Package C: Auth and Account Lifecycle

Depends on:
1. Package A

Can run in parallel with:
1. Package B

Outputs:
1. `User` model
2. signed-cookie session auth
3. sign-up, sign-in, and sign-out
4. email verification
5. password reset
6. role and state guards
7. Turnstile verification service
8. account-state restrictions on post, comment, and vote actions

Done when:
1. sign up works
2. sign in works
3. password reset works
4. unverified users cannot interact
5. suspended and banned users are blocked
6. tests cover auth flows and permission gates

Stop and ask user if:
1. Turnstile keys are needed
2. SMTP credentials are needed

### Package D: Core Domain Models and Validations

Depends on:
1. Package A
2. Package C for user references

Outputs:
1. `Tag`
2. `Post`
3. `PostTag`
4. `Comment`
5. `PostVote`
6. `CommentVote`
7. `Report`
8. `ModeratorAction`
9. all type-specific validations
10. all counter-cache and score update logic

Done when:
1. the schema matches this plan
2. validations enforce every post-type rule
3. vote uniqueness and cached counts work
4. report uniqueness works
5. tests cover model constraints

Stop and ask user if:
1. the tag taxonomy needs editorial decisions for launch seeding

### Package E: Feed, Tag Pages, and Ranking Read Path

Depends on:
1. Package D
2. Package B

Can run in parallel with:
1. Package F once shared post partials exist

Outputs:
1. home feed
2. sort tabs:
   1. Hot
   2. New
   3. Top
3. top-window dropdown:
   1. day
   2. week
   3. month
   4. all
4. post-type multi-filter
5. single-tag filter
6. tag page route
7. ranking service object
8. recurring hot-score refresh job

Done when:
1. feed state is URL-driven
2. hot, new, and top all work
3. types filter works
4. tag filter works
5. the tag page works
6. only `published` posts appear in feed results
7. ranking tests pass

Stop and ask user if:
1. ranking behavior appears to conflict with the product intent

### Package F: Submit Flow, Assets, and Hype Linter

Depends on:
1. Package D
2. Package B

Outputs:
1. `/submit` type picker
2. type-specific post forms
3. Active Storage integration
4. image and video validation
5. preview UI
6. style-guide UI
7. client-side hype-linter
8. server-side linter flag mirror
9. author post editing
10. rewrite-requested edit recovery

Done when:
1. each post type can be created with correct validations
2. media rules are enforced exactly
3. the linter warns but does not block
4. preview matches saved output closely
5. the edit flow republishes rewrite-requested posts

Stop and ask user if:
1. R2 credentials or bucket names are needed

### Package G: Comments and Votes

Depends on:
1. Package D
2. Package E for post detail context

Outputs:
1. threaded comments
2. reply composer
3. comment sorting
4. post voting
5. comment voting
6. visible vote counts
7. tombstone rendering for removed comments

Done when:
1. the nesting limit is enforced
2. top, new, and controversial sorts work
3. votes mutate counters correctly
4. sorting updates correctly after vote changes
5. tests cover nested replies and vote transitions

Stop and ask user if:
1. no stop expected

### Package H: Profiles and Static Pages

Depends on:
1. Package D
2. Package E
3. Package G

Outputs:
1. profile page
2. post history filter by type
3. comment history
4. static pages:
   1. about
   2. rules
   3. faq
   4. privacy
   5. terms

Done when:
1. the profile stays minimal
2. no status-game UI appears
3. static pages render from locale or content files
4. rewrite-requested posts remain visible on the author profile

Stop and ask user if:
1. legal copy needs anything beyond generic placeholders

### Package I: Moderation and Tag Management

Depends on:
1. Package D
2. Package E
3. Package G

Outputs:
1. report buttons
2. reports queue
3. target review views
4. rewrite-request flow
5. remove and restore flows
6. user suspension and ban flow
7. tag CRUD for moderators
8. moderator audit log

Done when:
1. moderators can process reports end to end
2. rewrite-requested visibility rules match this plan
3. removed posts are hidden correctly
4. removed comments show tombstones
5. all moderator actions are logged

Stop and ask user if:
1. moderation policy needs expansion beyond the specified minimum

### Package J: Mailers, Rate Limits, and Spam Hardening

Depends on:
1. Package C
2. Package F
3. Package G
4. Package I

Outputs:
1. reply alert mailers
2. email preference toggle
3. `Rack::Attack` rules
4. honeypot checks
5. minimum submit time checks
6. disposable email blocklist
7. Cloudflare cache headers for anonymous pages

Done when:
1. reply emails send only for allowed cases
2. throttles apply to the correct actions
3. suspicious signups and submits are blocked
4. anonymous feed and post pages emit cache-friendly headers

Stop and ask user if:
1. SMTP credentials are needed
2. production cache policy requires dashboard configuration

### Package K: Deployment, CI, and Launch Hardening

Depends on:
1. every prior package

Outputs:
1. finished GitHub Actions CI
2. Render blueprint config
3. production environment variable checklist
4. release command wrapper
5. backup and restore notes
6. launch smoke test checklist

Done when:
1. CI passes on the full suite
2. the app can deploy via Render blueprint
3. the health check is green
4. migrations run through `bin/render-release`
5. the launch checklist exists and can be executed step by step

Stop and ask user if:
1. any dashboard action, billing action, DNS change, or secret entry is required

## 11. Human-Only Actions

Agents must stop before these. The user must do them manually.

### 11.1 Cloudflare and Vercel Registrar

Goal: keep the registrar at Vercel and move DNS authority to Cloudflare.

User steps:
1. Sign in to Cloudflare.
2. Add the site `permanentunderclass.me`.
3. Choose the free plan.
4. Cloudflare will show two assigned nameservers. Copy them.
5. Sign in to Vercel.
6. Open the domain registrar settings for `permanentunderclass.me`.
7. Replace the current nameservers with the two Cloudflare nameservers.
8. Wait for the Cloudflare zone status to become active.
9. In Cloudflare R2, create these buckets:
   1. `permunderclass-media-production`
   2. `permunderclass-media-staging`
10. Create an R2 API token with read and write access limited to those buckets.
11. In Cloudflare Turnstile, create:
   1. one production widget for `permanentunderclass.me`
   2. one non-production widget for local and preview domains
12. Record these secrets for later entry into Render:
   1. Turnstile site key
   2. Turnstile secret key
   3. R2 access key id
   4. R2 secret access key
   5. R2 account id

Do not ask an agent to do these in a dashboard session.

### 11.2 Resend

Goal: enable transactional email for verification, password reset, and reply alerts.

User steps:
1. Create or sign in to Resend.
2. Add sending domain `mail.permanentunderclass.me`.
3. In Cloudflare DNS, add the Resend-provided DNS verification records.
4. Wait for domain verification.
5. Create SMTP credentials or use the Resend API key as SMTP password according to Resend's current docs.
6. Record:
   1. SMTP host
   2. SMTP port
   3. SMTP username
   4. SMTP password
   5. default from address, for example `noreply@mail.permanentunderclass.me`

Do not ask an agent to create or paste these secrets.

### 11.3 Render

Goal: deploy the app from repo configuration, not from ad hoc dashboard clicks.

User steps:
1. Push the repository to GitHub.
2. Sign in to Render.
3. Create a new Blueprint from the GitHub repository.
4. Let Render read `render.yaml`.
5. Create the resources defined by the blueprint:
   1. web service
   2. worker service
   3. Postgres instance
6. Enter the required environment variables from the checklist below.
7. After the first deploy, copy the Render default hostname.
8. In Cloudflare DNS, create proxied DNS records for:
   1. apex `permanentunderclass.me`
   2. `www`
9. In Render, add both custom domains:
   1. `permanentunderclass.me`
   2. `www.permanentunderclass.me`
10. Confirm `/up` returns 200 on the custom domain before public launch.

Required environment variables:
1. `RAILS_ENV=production`
2. `APP_HOST=permanentunderclass.me`
3. `FORCE_SSL=true`
4. `RAILS_MASTER_KEY`
5. `DATABASE_URL`
6. `R2_BUCKET=permunderclass-media-production`
7. `R2_ACCOUNT_ID`
8. `R2_ACCESS_KEY_ID`
9. `R2_SECRET_ACCESS_KEY`
10. `TURNSTILE_SITE_KEY`
11. `TURNSTILE_SECRET_KEY`
12. `SMTP_ADDRESS`
13. `SMTP_PORT`
14. `SMTP_USERNAME`
15. `SMTP_PASSWORD`
16. `SMTP_DOMAIN=mail.permanentunderclass.me`

Do not ask an agent to paste secrets into Render.

### 11.4 Initial Launch Curation

These are editorial and operational choices the user must own:
1. confirm the first moderator account
2. decide the initial seed tag list
3. decide whether public signups open immediately or after private testing
4. review About, Rules, FAQ, Privacy, and Terms content before launch

## 12. Deployment Plan

1. Deploy via Render blueprint from `render.yaml`.
2. Use Dockerfile deployment so ffmpeg and ffprobe can be installed predictably for video validation.
3. The web service runs the Rails app.
4. The worker service runs `bin/worker`.
5. The release command runs `bin/render-release`.
6. Postgres is managed by Render.
7. Object storage is Cloudflare R2.
8. Cloudflare proxies the site and caches anonymous GET traffic.
9. Cache rules:
   1. bypass cache when a session cookie is present
   2. cache the anonymous home feed for 60 seconds
   3. cache anonymous tag pages for 60 seconds
   4. cache anonymous post detail pages for 60 seconds
10. Static assets use long-lived cache headers.

## 13. CI

GitHub Actions must run:
1. tests via `bin/test`
2. lint via `bin/lint`
3. security checks via `bin/security`
4. Docker build verification

Minimum CI checks:
1. unit and model tests
2. request and integration tests
3. system tests for critical flows
4. RuboCop
5. ERB lint if adopted
6. Brakeman
7. bundle audit or equivalent

## 14. Testing Strategy

Test depth should match a solo-maintained v1 community site.

Must-have automated coverage:
1. auth flows
2. email verification
3. password reset
4. per-type post validations
5. media validation
6. ranking math
7. feed filtering and sorting
8. nested comments
9. vote transitions
10. rewrite-request behavior
11. moderation permissions
12. rate limiting boundaries

Must-have system tests:
1. anonymous browsing
2. sign up and verify
3. create a `shipped` post
4. create a `build` post with image
5. create a `build` post with short mp4
6. create a `discussion` post
7. vote on a post
8. vote on a comment
9. reply to a comment
10. sort comments
11. report a post
12. a moderator requests a rewrite
13. an author edits a rewrite-requested post and it returns to the feed
14. a reply alert email is enqueued

## 15. Cost Guardrails

These are rough monthly estimates, not guarantees.

### 15.1 Pre-launch or Private Development

1. Render web starter: about `$7`
2. Render worker starter: about `$7`
3. Render Postgres basic: about `$6`
4. Cloudflare free: `$0`
5. R2: near `$0` to low single digits
6. Resend free tier: `$0`

Expected total: about `$20` to `$30`

### 15.2 Around 1k DAU

Likely configuration:
1. keep the starter worker or move the worker up if mail or job volume demands it
2. the web service may remain starter or move to standard
3. Postgres may move to the next tier

Expected total: about `$30` to `$70`

### 15.3 Around 10k DAU

Likely configuration:
1. web on Render standard or higher
2. worker on standard or higher
3. Postgres upgraded
4. R2 and email still modest unless media volume spikes

Expected total: about `$80` to `$200`

The first scaling moves after v1, if needed, are:
1. increase Render service sizes
2. keep Cloudflare cache aggressive for anonymous traffic
3. only add Redis later if Solid Cache-backed throttling becomes the bottleneck

Redis is not part of the v1 plan.

## 16. Definition of Done

The v1 plan is complete when all of the following are true:
1. all required routes exist
2. all three post types work with correct validations
3. the feed supports hot, new, top, and top time windows
4. tag filtering works
5. post and comment voting work with visible counts
6. threaded comments work up to depth 8
7. profiles are minimal and filterable
8. the moderation queue and rewrite-request flow work exactly as specified
9. rate limiting and spam protections are active
10. email verification, password reset, and reply alerts work
11. CI passes
12. Render deployment is live
13. Cloudflare is fronting the site
14. the user has completed the human-only actions
15. static pages for About, Rules, FAQ, Privacy, and Terms are present
16. no excluded v1 features have been added
17. `PLAN.md` and the implementation still match

## 17. Operating Rule For Agents

When implementation questions arise:
1. follow this plan first
2. follow concrete repo manifests and wrappers for command syntax once they exist
3. if code and plan diverge materially, stop and ask the user before changing either
4. do not quietly expand scope
5. do not add excluded features under the label of convenience
