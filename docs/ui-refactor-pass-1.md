# UI Refactor Pass 1 & 2

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
