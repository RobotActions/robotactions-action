# Changelog

Versioning follows [semver](https://semver.org).

While this is `0.x`, semver permits breaking changes in a minor bump, so there
is deliberately **no floating `v0` tag** — pin an exact version. From `v1.0.0`
onward, `.github/workflows/release.yml` moves the major tag (`v1`) to each
release and pinning to that is the recommended usage.

## v0.2.0

- Also export `GRID_URL` and `GRID_HOST`. The action previously exported only
  the `RA_`-prefixed names, but the template projects read the unprefixed ones,
  so a workflow using the action still had to set them by hand — which defeated
  the point. Found by actually wiring it into robotactions-automation.

## v0.1.0

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
