# CI runtime notes

Audit date: 2026-10-03. Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Runner

The workflow explicitly uses `ubuntu-26.04` rather than the moving `ubuntu-latest` label. GitHub announced Ubuntu 26.04 runner general availability on 2026-09-17 and a gradual `ubuntu-latest` migration from 2026-10-19 through 2026-11-19. Pinning the named runner avoids an unannounced image change during that transition. Revisit the runner label after GitHub's migration and support policy changes.

Sources: [GitHub announcement: Ubuntu 26.04 runner availability and latest-label migration](https://github.blog/changelog/2026-09-17-ubuntu-26-generally-available-and-latest-migration/), [GitHub Actions runner images](https://github.com/actions/runner-images).

## Actions

As checked on the audit date, the workflow uses the current stable major release lines:

| Action | Workflow reference | Release page checked |
|---|---|---|
| `actions/checkout` | `@v7` | [Releases](https://github.com/actions/checkout/releases) |
| `actions/setup-node` | `@v7` | [Releases](https://github.com/actions/setup-node/releases) |
| `actions/configure-pages` | `@v6` | [Releases](https://github.com/actions/configure-pages/releases) |
| `actions/upload-pages-artifact` | `@v5` | [Releases](https://github.com/actions/upload-pages-artifact/releases) |
| `actions/deploy-pages` | `@v5` | [Releases](https://github.com/actions/deploy-pages/releases) |

The workflow requests Node.js 24 for JavaScript actions and project scripts. Action references use their documented major tags so patch releases remain current; they are not pinned to immutable commit SHAs.

## Validation separation

The Chromium browser suite is required for Pages deployment. Firefox is a separate advisory job (`continue-on-error: true`) because the Firefox matrix is additional cross-browser evidence and should not make a Firefox-only transient failure block `main`. A passed advisory job is recorded as such; local browser results are separately documented in `browser-compatibility.md`.
