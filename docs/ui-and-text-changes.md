# UI and Text Changes

## What Changed

Replaced sample and package-era copy in the shared shell with plain user-facing instructions. The header, anonymous navigation status, footer, static pages, and post preview panel now use straightforward text that explains how the site works instead of placeholder or implementation-focused language.

The footer was also simplified so it only shows useful site guidance and page links. Unused placeholder copy in the old `home` locale section was removed from the registry.

## Files Added or Modified

- `config/locales/en.yml`
- `app/views/shared/_footer.html.erb`
- `test/integration/home_page_test.rb`
- `docs/ui-and-text-changes.md`

## Verification

Ran the repository wrapper commands:

```bash
bin/test
bin/lint
```

Also reviewed the updated locale diff to confirm that dev-facing placeholder language was removed from the visible shell and the footer structure still matched the available locale keys.

## Follow-up Work or Known Limitations

- The privacy and terms pages now contain plain-language operational text, but they are still product copy rather than counsel-reviewed legal documents.
- The `https://` field placeholder for URL inputs remains in place because it is an input hint rather than sample marketing copy.
