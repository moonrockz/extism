# Docs site driver

`moonrockz/extism-site` builds, checks and serves the docs site of this repository with
[`moonrockz/telescope/host`](https://github.com/moonrockz/telescope). It is a docs tool and is not
published.

| Command | Does |
| --- | --- |
| `site build [--json]` | Builds `_site/` from `site/site.json`, `docs/` and `site/pages/` |
| `site check [--json]` | Checks the pages, links and resources of `_site/` |
| `site serve [--port <1-65535>]` | Serves `_site/` at `http://127.0.0.1:<port>/extism/` until SIGINT or SIGTERM; the port is 4173 if you do not give one |

Run it from the repository root through `mise run build:site`, `check:site` and `dev:site`.

With `--json`, `build` and `check` write one JSON document to stdout: `command`, `state`, `exitCode`,
`diagnostics` (each with `source`, `line` and `message`), and `result: {out}` on success or
`error: {code, message}` on failure. The human messages go to stderr. The exit status is 0 for
success, 1 for a build or check failure and 2 for a usage error.
