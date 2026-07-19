# Codex Pulse architecture

## Product contract

Codex Pulse is a native macOS menu-bar utility. It shows the remaining percentage for the primary Codex weekly limit in the menu bar and opens a compact dashboard with all returned Codex limit buckets, reset time, account plan, reset-credit count, connection state, and last refresh time.

The display refreshes once per second. Requests are sequential so a slow request never creates a backlog.

## Data source

Use the locally installed `codex app-server --stdio` process and its JSON-line protocol:

1. Send `initialize` with client name and version.
2. Send the `initialized` notification.
3. Call `account/rateLimits/read` with `params: null` once per refresh.
4. Decode `rateLimitsByLimitId`, falling back to `rateLimits` for older Codex versions.

The application must not open, parse, copy, or persist `~/.codex/auth.json`. Authentication remains owned by the official local Codex process.

## Shared types

Backend owns these names for the UI:

- `QuotaSnapshot`: decoded response plus `fetchedAt`.
- `RateLimitBucket`: one limit bucket, including optional primary and secondary windows.
- `RateLimitWindow`: used percent, duration, and reset timestamp.
- `CodexQuotaService`: actor that returns `QuotaSnapshot`.
- `QuotaMonitor`: main-actor observable state that polls once per second.

Frontend reads `QuotaMonitor.snapshot`, `QuotaMonitor.connectionState`, `QuotaMonitor.lastError`, and calls `start()`, `refreshNow()`, or `stop()`.

## Trust boundary

All JSON from the subprocess is untrusted input. Validate response IDs, required fields, percentage range, timestamps, and process termination. Surface failure clearly and retry without replacing errors with guessed quota values.
