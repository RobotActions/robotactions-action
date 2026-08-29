# RobotActions Device Cloud — GitHub Action

Point an existing test suite at the [RobotActions](https://robotactions.com)
grid: real Android and iOS devices plus browser nodes, behind one endpoint that
speaks WebDriver, Appium and Playwright.

This is a **setup** action. It resolves the endpoint, exports the environment
your framework already reads, and gets out of the way — it does not wrap your
test command or dictate a runner.

## Usage

```yaml
- uses: RobotActions/robotactions-action@v0.2.0
  with:
    api-token: ${{ secrets.RA_API_TOKEN }}

- run: npx wdio run wdio.conf.ts
```

With a suite label so runs group in the dashboard:

```yaml
- uses: RobotActions/robotactions-action@v0.2.0
  with:
    api-token: ${{ secrets.RA_API_TOKEN }}
    test-suite: Nightly regression
    release-id: ${{ github.sha }}
```

## Inputs

| Input | Required | Default | |
|---|---|---|---|
| `api-token` | yes | — | Pass from an encrypted secret, never inline |
| `grid-url` | no | `grid.robotactions.com` | Bare host or full URL |
| `auth` | no | `header` | `header` or `path` |
| `test-suite` | no | — | Suite label recorded per session |
| `release-id` | no | — | Release identifier recorded per session |

### Which `auth`?

Leave it as `header` unless you know otherwise. It sends
`Authorization: Bearer <token>`.

`path` uses a `/t/<token>/` URL prefix instead, for clients or proxies that
expect it. Note that Node-based clients — WebdriverIO among them — **cannot**
use credentials embedded in a URL at all, because Node 18+ `fetch` rejects
them. The Python and Java clients can.

## Outputs

| Output | |
|---|---|
| `grid-url` | WebDriver/Appium endpoint, including the token prefix under `path` auth |
| `playwright-ws` | Playwright remote websocket endpoint |

## Exported environment

`RA_API_TOKEN`, `RA_GRID_URL`, `RA_GRID_HOST`, plus the unprefixed `GRID_URL`,
`GRID_HOST` and `AUTH_TOKEN` that the template projects read. `RA_TESTSUITE` and `RA_RELEASE_ID` are exported only
when supplied.

## Examples by framework

```yaml
# WebdriverIO — wdio.conf.ts reads AUTH_TOKEN / RA_GRID_URL
- run: npx wdio run wdio.conf.ts

# Playwright — connect to the remote endpoint
- run: npx playwright test
  env:
    PW_WS: ${{ steps.grid.outputs.playwright-ws }}

# Selenium / Appium — point the remote driver at the grid
- run: pytest tests/
```

Complete runnable projects for WebdriverIO, Appium, Playwright, Selenium,
Espresso and XCTest live in
[robotactions-automation](https://github.com/RobotActions/robotactions-automation).

## Security

The token is masked from logs on the first line of the action, before it can
reach any later output. Under `path` auth the resolved URLs contain the token,
so those are masked too. Always pass it from an encrypted secret — an inline
token is readable by anyone who can see the workflow file.

## License

MIT
