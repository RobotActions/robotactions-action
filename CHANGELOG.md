# Changelog

Versioning follows [semver](https://semver.org). Marketplace consumers pin to
the floating major tag (`@v1`), which is moved to each release automatically by
`.github/workflows/release.yml`.

## v1.0.0

First release.

- Setup-style action: resolves the grid endpoint and exports the environment
  the framework templates already read, rather than wrapping the test command.
- Accepts a bare host or a full URL, and infers scheme and port — including
  `ws` rather than `wss` for a local http grid.
- Both auth modes. `header` is the default because Node 18+ rejects credentials
  embedded in a URL, which rules the URL form out for fetch-based clients such
  as WebdriverIO.
- Optional `test-suite` and `release-id` labels for grouping runs.
- The token is masked before any other output, and the resolved URLs are masked
  too since they carry it under `path` auth.
- Empty token or an unrecognised `auth` value fails the step rather than
  producing a session that silently is not authenticated.
