# Package B: Layout, Tokens, and Copy Registry

## What Changed

Implemented the first real application shell on top of the Package A Rails bootstrap. The app now has a root page, shared header, navigation, footer, a responsive layout wrapper, tokenized CSS variables, and a structured locale registry for visible interface copy. The placeholder copy stays generic and functional and keeps the interface aligned with the restrained visual brief in `PLAN.md`.

## Files Added or Modified

### Routing and Controller
- `config/routes.rb` — added the root route for the application shell
- `app/controllers/home_controller.rb` — added the placeholder shell page controller

### Layout and Shared Views
- `app/views/layouts/application.html.erb` — added the shell frame, skip link, meta description, shared header/footer rendering, and main content wrapper
- `app/views/shared/_header.html.erb` — added the shared site header and brand area
- `app/views/shared/_site_nav.html.erb` — added the shared navigation surface
- `app/views/shared/_footer.html.erb` — added the shared footer surface
- `app/views/shared/_flash.html.erb` — added a shared flash-message surface inside the application shell for later packages
- `app/views/home/index.html.erb` — added the root placeholder page using locale-backed copy only

### Helpers and Copy Registry
- `app/helpers/application_helper.rb` — added page title and active nav helpers for layout reuse
- `config/locales/en.yml` — expanded from a minimal app title file into a structured registry for layout, navigation, home, and footer copy

### Styles
- `app/assets/stylesheets/application.css` — replaced the empty scaffold manifest with design tokens, responsive shell styles, typography, borders, and global underlined link rules

### Tests
- `test/integration/home_page_test.rb` — verifies the shared shell renders at the root path and uses locale-backed copy
- `test/helpers/application_helper_test.rb` — verifies shared title and active-nav helper behavior
- `test/models/stylesheet_contract_test.rb` — verifies the stylesheet defines core tokens, underlined links, responsive breakpoints, and avoids forbidden visual effects

## Verification

### Automated Checks
```bash
docker compose run --rm app bin/test
docker compose run --rm app bin/lint
docker compose run --rm app bin/security
```
Result: all commands completed successfully after the Package B changes.

### Layout Contract Checks
Verified by test coverage and direct response assertions that:
- `/` responds successfully
- the shell includes `header`, `nav`, `main`, and `footer`
- the page title and meta description are set from locale-backed copy
- no `translation missing` output appears in the rendered shell
- the stylesheet includes token definitions and underlined links
- the stylesheet does not include shadows or gradients
- helper behavior for shared page titles and active nav state is covered by tests

Additionally, the base layout now renders a shared flash partial so later packages can surface notices and errors without changing the shell again.

### Responsive Shell Review
Reviewed the shell CSS and layout structure to confirm it uses a single-column mobile layout that expands to multi-column header, content, and footer layouts at wider viewports without introducing cards, shadows, or gradients.

## Follow-up Work and Limitations

- The navigation intentionally exposes only the root page today. Auth, feed, submit, profile, and moderation routes belong to later packages.
- Footer copy is informational for now; real static pages such as About, Rules, FAQ, Privacy, and Terms are deferred to Package H.
- The locale registry is structured for extension, but it does not yet contain the full copy set for future packages.
- The root page is a placeholder shell, not the final feed experience. Package E will replace this with the real public feed.
