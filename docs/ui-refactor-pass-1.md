# UI Refactor Passes 1, 2, 3, 4, 5, 6, 7, 8, 9

## Pass 9 — What Changed

Two small follow-ups on the profile page.

1. `.button` anchors are no longer underlined. `.button` is the shared pill used by form submits (which have no underline) and by a few `<a class="button">` usages — `Review account` on the profile moderator panel (`app/views/users/show.html.erb`), `Edit` on post show (`app/views/posts/show.html.erb`), and the picker CTAs (`app/views/posts/type_picker.html.erb`). The browser default `a { text-decoration: underline }` was bleeding through because `.button` never declared its own `text-decoration`. Added `text-decoration: none` to the `.button` rule in `app/assets/stylesheets/application.css` so every anchor-styled button now reads as a button, not a link.
2. Removed the `TYPE` eyebrow above the post-type filter row on the profile page. `All types  Shipped  Build  Discussion` is now a single inline text-link row — the muted colour and the underline-on-active styling are enough to distinguish it from the `Posts / Comments` chip tabs above. Dropped the now-unused `.profile-filters__subgroup` wrapper in CSS, the `profiles.filters.post_type_heading` locale key, and the extra `<p class="eyebrow">` + nested `<div class="filter-group">` wrapper in the view — the `<nav>` goes back to just `class="filter-group"`.

Files touched:

- `app/views/users/show.html.erb`
- `app/assets/stylesheets/application.css`
- `config/locales/en.yml`
- `docs/ui-refactor-pass-1.md`

Verification:

- `bin/test`: 248 runs, 892 assertions, 0 failures, 0 errors, 0 skips.
- Screenshot of `/u/admin_test?post_type=build`: "Build" is the sole underlined link in the row, no `TYPE` eyebrow above it, chip tabs still clearly primary.
- Spot-checked the three `<a class="button">` usages with a computed-style check via the CSS cascade: the element selector `a { text-decoration: underline }` is now overridden by `.button { text-decoration: none }`. `<input type="submit" class="button">` is unaffected because inputs had no underline to begin with.

Follow-up / known limitations:

- The `.profile-filters__subgroup` rule was added in Pass 8 and removed in Pass 9; no other caller ever adopted it.

---

## Pass 8 — What Changed

Profile page post-type filter row is now visually subordinate to the Posts/Comments tabs above it, and the pre-existing active-state bug on that row was fixed.

1. `app/views/users/show.html.erb`: restructured the post-type `<nav>`. The row now carries a small `Type` eyebrow and swaps `.filter-link` (bordered chip) for `.filter-inline-link` (text-only). This makes the control read as a secondary filter rather than a duplicate set of primary tabs. Same feature, new hierarchy:
   ```
   [Posts] [Comments]      ← chip tabs (primary)
   TYPE
   All types  Shipped  Build  Discussion   ← muted text links (secondary, active = underlined)
   ```
2. `app/views/users/show.html.erb`: fixed the active-state comparison for individual post types. The loop key from `post_type_labels` (=`I18n.t("post_types")`) is a symbol (`:build`), while `@post_type` set by `UsersController#profile_post_type` is a string (`"build"`). The previous `@post_type == post_type` comparison silently never matched, so no specific post-type link ever got `is-active` — only "All types" (which uses `@post_type.blank?`). Changed the comparison to `@post_type == post_type.to_s`. Pure view change, no controller/helper touched.
3. `app/assets/stylesheets/application.css`: added `.filter-inline-link` (padding/border stripped, muted colour, underline on `.is-active`) and `.profile-filters__subgroup` (grid wrapper that stacks the `Type` eyebrow above the inline links with `gap: var(--space-2)`). `.filter-link` is unchanged — it still powers the primary Posts/Comments tabs on the profile, `Hot/New/Top` on the feed, and similar chip-style controls elsewhere.
4. `config/locales/en.yml`: added `profiles.filters.post_type_heading: "Type"` as the visible label. `post_type_label` (`"Filter posts by type"`) is kept as the `aria-label` so screen readers still get the longer description.

Files touched:

- `app/views/users/show.html.erb`
- `app/assets/stylesheets/application.css`
- `config/locales/en.yml`
- `docs/ui-refactor-pass-1.md`

Verification:

- `bin/test`: 248 runs, 892 assertions, 0 failures, 0 errors, 0 skips.
- Curled `/u/admin_test?post_type=build`: the rendered HTML now contains `<a class="filter-inline-link is-active" ...>Build</a>`. On `/u/admin_test` (no filter) it is `All types` that carries `is-active`. Before the fix neither `Build`, `Shipped`, nor `Discussion` could ever receive the active class.
- Screenshot of `/u/admin_test?post_type=build` confirms "Build" is underlined with the `text-underline-offset: 0.3em` styling, and the other type links stay muted.

Follow-up / known limitations:

- The active-state string-vs-symbol comparison bug almost certainly exists in other places that iterate `t("post_types")` for filtering. A broader sweep was out of scope for this pass. The same `.to_s` fix pattern should apply if it surfaces elsewhere.
- If another page ever wants the same "eyebrow + inline links" subgroup treatment, `.profile-filters__subgroup` can be renamed / promoted; it was named for this page because this is the only current use.

---

## Pass 7 — What Changed

Rewrote the profile page (`/u/:pseudonym`) to follow the same auth-shell aesthetic as the sign-in and sign-up pages: a single small mono/uppercase eyebrow acting as the title, no subtitle, no horizontal rules, and tighter activity rhythm. Backend (`UsersController`, model, routes) was not touched — only the view, CSS, and locale copy that feeds the view.

1. `app/views/users/show.html.erb`:
   - Replaced the `eyebrow "Profile" + h1 pseudonym + intro lede` stack with a single `<p id="profile-title" class="eyebrow">@profile_user.pseudonym</p>` that renders as the all-caps mono label (e.g. `ADMIN_TEST`). `aria-labelledby="profile-title"` on the `<section>` still wires the accessible name.
   - Inside the own-profile Preferences block, dropped the `h2 "Email alerts"` section title and the explanatory paragraph. Kept the `Preferences` eyebrow, the reply-alerts checkbox, and the submit button — matching the auth-shell rhythm (eyebrow + form).
   - Kept the Posts/Comments toggle, the post-type filter chips, the activity list, the pagination partial, the empty-state message, the `reports/form` disclosure, and the moderator review link. Functionality is identical.
2. `app/assets/stylesheets/application.css`:
   - Removed `.profile-header` from the shared `padding-top: var(--space-4); border-top: 1px solid var(--color-border)` rule. That rule had been drawing the horizontal line above the old `PROFILE` eyebrow. `.content-page__section` and `.activity-item` still keep the border-top so static pages (`About`, `Rules`, …) and moderator activity lists are unaffected.
   - Added scoped overrides that only fire inside `.profile-layout`:
     ```css
     .profile-layout .activity-item { padding-top: 0; border-top: 0; gap: var(--space-2); }
     .profile-layout .activity-list { gap: var(--space-6); }
     ```
     Effect: profile activity items drop the divider line, get tighter internal spacing (meta → title → body pulled from 1rem to 0.5rem), and sit 2rem apart from each other so each post/comment still reads as a discrete item without a rule between them. Because the override is descendant-scoped, `.activity-item` usage on moderator dashboards (`mod/reports`, `mod/users`, `mod/tags`, `mod/shared/_action_log`) is untouched.
3. `config/locales/en.yml`:
   - Removed the now-unused `profiles.eyebrow`, `profiles.intro`, `profiles.preferences.title`, and `profiles.preferences.intro` keys.
   - Kept `profiles.title` (`"%{pseudonym}"`, feeds the browser tab via `content_for :title`) and `profiles.description` (meta description).
4. `test/integration/profile_pages_test.rb`: swapped the first smoke assertion from `assert_select "h1", users(:active_member).pseudonym` to `assert_select "p.eyebrow#profile-title", users(:active_member).pseudonym` to match the new markup. The remaining assertions (`.activity-item` text matches, filter behaviour, moderator-visible removed posts, preferences patch) were already structural and still pass.

Files touched:

- `app/views/users/show.html.erb`
- `app/assets/stylesheets/application.css`
- `config/locales/en.yml`
- `test/integration/profile_pages_test.rb`
- `docs/ui-refactor-pass-1.md`

Verification:

```bash
docker exec permunderclassme-app-1 bin/test
```

- `bin/test`: 248 runs, 892 assertions, 0 failures, 0 errors, 0 skips.
- Headless screenshot of `/u/admin_test` (1280×900) confirms the new layout: `ADMIN_TEST` eyebrow at the top, Posts/Comments toggle, post-type chips, a single clean post card with no divider lines, and the footer sitting below the fold (Pass 6 behaviour still holds).

Follow-up / known limitations:

- The pseudonym now renders as the eyebrow only. For users with very short pseudonyms that might feel light; the filter chips and activity list carry most of the visual weight. If this ever feels too subdued, the eyebrow could be promoted to a slightly larger type step without reintroducing the old `h1 + subtitle` stack.
- Moderator dashboards that use `.activity-item` still show the top border between items because the tighter-gap override is scoped to `.profile-layout`. If those pages should get the same quieter treatment, the scoping can be widened in a follow-up.
- The page no longer contains an `h1`. The document is still uniquely labelled through `<title>` and the aria-labelled section, matching the choice already made on the auth pages.

---

## Pass 6 — What Changed

Pushed the site footer below the viewport fold on short-content pages so it is no longer visible by default. Users now scroll to reveal it on every page.

1. `app/assets/stylesheets/application.css`: added `min-height: 100vh` to `.site-main`. The layout was already a flex column (`.site-shell` is `min-height: 100vh; display: flex; flex-direction: column;`) with `.site-main { flex: 1 }` holding the footer to the bottom of the viewport — classic sticky-footer behavior. Promoting main to `min-height: 100vh` makes the main area alone at least one viewport tall, so header + main + footer always exceeds the viewport and the footer starts below the fold.

No markup changes were needed.

Behavior:

- Short pages (e.g. `/sign-in`, `/sign-up`): main fills the viewport; footer is hidden initially and revealed by scrolling down.
- Long pages (e.g. `/` with a long feed, post detail pages): unchanged — content already exceeded the viewport, footer already required scrolling.

Files touched:

- `app/assets/stylesheets/application.css`
- `docs/ui-refactor-pass-1.md`

Verification:

```bash
docker exec permunderclassme-app-1 bin/test
```

- `bin/test`: 248 runs, 892 assertions, 0 failures, 0 errors, 0 skips.
- Headless viewport (1280×720) at `/sign-in`: footer top y=817, viewport bottom y=720 — footer is 97px below the fold.
- Headless viewport at `/`: same — footer top y=817, viewport bottom y=720. After `scroll`, the footer is fully in view.

Follow-up / known limitations:

- The trade-off is extra empty space below the content on very short pages (what used to be the "reserve" space is now at least one full viewport). This is the direct consequence of hiding the footer by default. If it ever feels excessive, the threshold can be tightened to `calc(100vh - <approx header height>)` at the cost of more coupling between header and main sizing.
- `100vh` is used for broad compatibility; on mobile browsers with a collapsible URL bar the value can be slightly larger than the visible area. If that ever matters visually we can switch to `100dvh`.

---

## Pass 5 — What Changed

Simplified the sign-in and sign-up pages. Removed redundant headings and subtitles so the eyebrow label sits directly above the form with natural grid spacing.

1. Sign-in page (`app/views/sessions/new.html.erb`):
   - Eyebrow text renamed from `Session` to `Sign in` (still rendered in the mono/uppercase/letter-spaced `.eyebrow` style, so it displays as `SIGN IN`).
   - Removed the `h1.hero__title.auth-shell__title` "Sign in" heading.
   - Removed the `.lede` intro paragraph ("Use the email address and password linked to your pseudonymous account.").
   - The `aria-labelledby="sign-in-title"` target (`id="sign-in-title"`) was moved from the removed `h1` onto the eyebrow `<p>`, so the section is still labeled for assistive tech.
2. Sign-up page (`app/views/users/new.html.erb`):
   - Removed the `h1.hero__title.auth-shell__title` "Create an account" heading.
   - Removed the `.lede` intro paragraph ("Use an email address and a pseudonym. Verification is required before posting, commenting, or voting.").
   - Kept the `Account` eyebrow unchanged.
   - `aria-labelledby="sign-up-title"` target moved onto the eyebrow `<p>`.
3. Locale cleanup (`config/locales/en.yml`):
   - `auth.sign_in.eyebrow`: `Session` → `Sign in`.
   - Removed unused `auth.sign_in.intro` and `auth.sign_up.intro` keys.
   - `auth.sign_in.title` and `auth.sign_up.title` are kept because they still feed the `content_for :title` browser-tab title.

The `.auth-shell` grid `gap: var(--space-3)` (0.75rem) is now what separates the eyebrow from the `.form-shell`. Screenshots at `/sign-in` and `/sign-up` confirm the title sits at natural spacing above the first input with no stray heading between them.

`.auth-shell__title` and `.hero__title` CSS rules were left in place because `password_resets/new.html.erb`, `password_resets/edit.html.erb`, `posts/type_picker.html.erb`, and `posts/_form.html.erb` still use `auth-shell__title`.

Files touched:

- `app/views/sessions/new.html.erb`
- `app/views/users/new.html.erb`
- `config/locales/en.yml`
- `test/integration/sign_up_flow_test.rb` (swapped `assert_select "h1", ...` for `assert_select "p.eyebrow", I18n.t("auth.sign_up.eyebrow")` since the `h1` no longer exists)
- `docs/ui-refactor-pass-1.md` (this entry)

Verification:

```bash
docker exec permunderclassme-app-1 bin/test
curl http://localhost:3000/sign-in
curl http://localhost:3000/sign-up
```

- `bin/test`: 248 runs, 892 assertions, 0 failures, 0 errors, 0 skips.
- `curl /sign-in` confirms: no `<h1>` in the auth shell, no `.lede` paragraph, `<p id="sign-in-title" class="eyebrow">Sign in</p>` is the sole label above the form. Browser tab still reads `Sign in · permanentunderclass.me`.
- `curl /sign-up` confirms: no `<h1>`, no `.lede`, `<p id="sign-up-title" class="eyebrow">Account</p>` is the sole label. Browser tab still reads `Create an account · permanentunderclass.me`.
- Headless screenshots captured of both pages; spacing between eyebrow and first input matches the rest of the auth shell's grid rhythm.

Follow-up / known limitations:

- None. The removed `intro` strings and `h1` elements were not referenced anywhere else in the app.

---

## Pass 4 — What Changed

Spacing polish only, no copy or structural changes:

1. `.site-header__inner` now uses `padding-block: var(--space-6) var(--space-3)` (2rem top, 0.75rem bottom) so the brand eyebrow + tagline sit visibly lower in the header with breathing room above.
2. Added a `.site-footer__section > * { margin: 0; }` rule. Each footer section is a grid, and the default `<p>` `margin-bottom` was stacking on top of the grid `gap`, leaving a ~1.5rem gap between the eyebrow label and the body/links. Resetting direct-child margins lets the grid `gap: var(--space-2)` (0.5rem) be the actual spacing, pulling the body text up close to its title.

Files touched:

- `app/assets/stylesheets/application.css`

Verification:

- `bin/test`: 248 runs, 892 assertions, 0 failures.
- `bin/lint`: 114 files, no offenses.

---

## Pass 3 — What Changed

Header compaction, footer restructure, and a more deliberate theme-toggle colour:

1. Added a `--color-theme-indicator` CSS variable. In light mode it is `#26262a` (the dark-mode page background); in dark mode it is `#f6f2e8` (the light-mode page background). The toggle uses this for both its background and border, so it always previews the mode the button would switch you into.
2. Gated the `.site-tagline` paragraph with `current_page?(root_path)` so the `Welcome to the permanent underclass` subtitle only shows on the home page. Every other page shows just the eyebrow site title.
3. Flattened the header nav:
   - The `.site-nav__list` is now a horizontal `flex-wrap: wrap` row at every width.
   - Removed the `Moderation` link from the logged-in menu.
   - Removed the `STATE` eyebrow/value block from the logged-in menu.
   - Dropped the `ACCOUNT` eyebrow so the pseudonym link sits inline with the other nav items.
   - Pulled the anonymous availability copy out of the list into a `.site-nav__note` paragraph directly under the horizontal list — keeps the info visible without stretching the first row.
   - Reduced `.site-header__inner` vertical padding from `var(--space-5)` to `var(--space-4)` and aligned brand/nav with `align-items: center` on desktop so the header is visibly shorter.
4. Restructured the footer:
   - `footer.site.title`, `footer.posts.title`, `footer.pages.title` now render inside the `.eyebrow` paragraph (the uppercase/mono label line).
   - Removed the `h2.site-footer__title` subheaders entirely, along with their `aria-labelledby` wiring.
   - The Pages section uses `aria-label` on its `<nav>` instead.
   - The `.site-footer__title` CSS rule was removed along with the unused `footer.*.eyebrow` locale keys (`Site`, `Posts`, `Pages`).
5. Removed now-unused locale keys: `nav.moderation`, `nav.account_label`, `nav.account_state_label`, `footer.site.eyebrow`, `footer.posts.eyebrow`, `footer.pages.eyebrow`.

Tests updated to match the new structure:

- `test/integration/session_flow_test.rb`: dropped the `.site-nav__status` assertion for the pending-verification state (the block no longer exists; the flash notice is still asserted).
- `test/integration/sign_up_flow_test.rb`: switched the selector from `.site-nav__status a[...]` to `.site-nav a[...]` since the pseudonym link no longer has a status wrapper.

Files touched:

- `app/views/shared/_header.html.erb`
- `app/views/shared/_site_nav.html.erb`
- `app/views/shared/_footer.html.erb`
- `app/assets/stylesheets/application.css`
- `config/locales/en.yml`
- `test/integration/session_flow_test.rb`
- `test/integration/sign_up_flow_test.rb`

Verification:

```bash
docker exec permunderclassme-app-1 bin/test
docker exec permunderclassme-app-1 bin/lint
```

- `bin/test`: 248 runs, 892 assertions, 0 failures, 0 errors, 0 skips.
- `bin/lint`: 114 files inspected, no offenses detected.
- `curl http://localhost:3000` confirms `.site-tagline` is present on home; `curl http://localhost:3000/about` confirms it is absent on non-home pages. Footer now shows `Using the site`, `What to post`, and `More information` as uppercased eyebrow labels with no `h2` siblings.

Follow-up:

- The logged-in nav will get narrower on tighter viewports; if the wrap still feels cluttered a future pass could collapse it into a compact menu on mobile.
- The availability note lives directly under the horizontal nav for anonymous users. If that two-row height feels wrong on home specifically, it can be trimmed later.

---

## Pass 2 — What Changed

Follow-up round of header polish on the same `ui-refactor` branch:

1. Brought the `permanentunderclass.me` site identifier back as the top-most element in the header, styled in the same eyebrow/mono/uppercase/letter-spaced treatment used by the `ACCOUNT`, `STATE`, and `TAG` labels elsewhere on the page.
2. Moved `Welcome to the permanent underclass` into a new `.site-tagline` paragraph directly below the eyebrow title so it now reads as a subtitle of the site identifier.
3. Removed the `border-bottom` from `.site-header` so the header no longer has a visible rule below it.
4. Removed the underlines from the nav hyperlinks on the right (`.site-nav__link`) and dropped the now-meaningless `text-decoration-thickness` from the `.is-active` variant. The bold weight remains the active-state indicator.
5. Reworked the theme toggle so the button fills with `var(--color-text)` in both modes. In light mode that reads as a small dark disc (hint: click to go dark). In dark mode it reads as a light disc (hint: click to go light). Hover/focus dims to `var(--color-muted)`.

Locale key layout in `config/locales/en.yml` is now:

- `app.name` → `permanentunderclass.me` (site identifier, also used for `<meta name="application-name">`)
- `app.title` → `permanentunderclass.me` (browser tab title suffix)
- `app.tagline` → `Welcome to the permanent underclass` (new key for the subtitle line)

Files touched in this pass:

- `config/locales/en.yml`
- `app/views/shared/_header.html.erb`
- `app/assets/stylesheets/application.css`

Verification:

```bash
docker exec permunderclassme-app-1 bin/test
docker exec permunderclassme-app-1 bin/lint
```

- `bin/test`: 248 runs, 894 assertions, 0 failures, 0 errors, 0 skips.
- `bin/lint`: 114 files inspected, no offenses detected.
- `curl http://localhost:3000` confirms the rendered `.site-title` reads `permanentunderclass.me`, `.site-tagline` reads `Welcome to the permanent underclass`, and the `.theme-toggle` button remains wired with the Stimulus controller.

---

## Pass 1 — What Changed

First pass of the `ui-refactor` branch, driven directly by user direction. Four user-facing changes shipped together:

1. Homepage site title changed from `permanentunderclass.me` to `Welcome to the permanent underclass`. The browser tab title (`app.title`) is left as `permanentunderclass.me` since it was not part of the request.
2. The header subtitle paragraph (`Posts from pseudonymous builders.`) was removed. The unused `header.summary` locale key and the orphaned `.site-header__summary` CSS rule were also removed.
3. The anonymous right-side status block had its `ACCESS` eyebrow removed and its copy replaced with `Create an account and verify your email to post, comment or vote.` The now-unused `nav.availability_label` locale key was also removed.
4. A subtle light/dark-mode toggle was added at the top-left of every page. It is a small unlabeled circular button styled to only register if someone is looking for it. Dark mode uses a grayish palette with light text, and the user's preference is persisted in `localStorage`. An inline script in the `<head>` applies the saved theme before the stylesheet loads, so there is no flash of the wrong theme on navigation.

## Files Added or Modified

- `app/views/layouts/application.html.erb` (inline FOUC guard script + toggle button)
- `app/views/shared/_header.html.erb` (removed subtitle paragraph)
- `app/views/shared/_site_nav.html.erb` (removed Access eyebrow)
- `config/locales/en.yml` (updated title, updated availability value, removed unused keys, added `theme_toggle.label`)
- `app/assets/stylesheets/application.css` (added `[data-theme="dark"]` variables, `--color-field-bg` variable, `.theme-toggle` styles, nudged the focused skip-link to avoid the toggle, removed the `.site-header__summary` rule)
- `app/javascript/controllers/theme_toggle_controller.js` (new Stimulus controller that reads/writes `localStorage` and sets `data-theme` on `<html>`)
- `docs/ui-refactor-pass-1.md` (this document)

## Verification

Ran the repo wrapper commands inside the already-running development container:

```bash
docker exec permunderclassme-app-1 bin/test
docker exec permunderclassme-app-1 bin/lint
```

- `bin/test`: 248 runs, 894 assertions, 0 failures, 0 errors, 0 skips.
- `bin/lint`: 114 files inspected, no offenses detected.

Also curled the running app at `http://localhost:3000` and confirmed:

- `a.site-title` renders `Welcome to the permanent underclass`
- No `.site-header__summary` element is present
- The right-hand block reads `Create an account and verify your email to post, comment or vote.`
- The `.theme-toggle` `<button>` is present with `data-controller="theme-toggle"` and the importmap registers `controllers/theme_toggle_controller`.

## Follow-up Work or Known Limitations

- The toggle uses `localStorage` and does not honour the OS-level `prefers-color-scheme` yet. A future pass could seed the initial theme from the system preference when nothing is stored.
- No automated test covers the JS toggle behaviour (the app does not yet have system tests for this layer). An integration test could at minimum assert the button is rendered and wired on every layout.
- The dark palette is a single grayish scheme. If the visual direction changes, the six dark-mode tokens in `application.css` are the only place to adjust.
- Future pages in this refactor may reveal additional hardcoded colors that need to be converted to CSS variables the same way `--color-field-bg` was.
