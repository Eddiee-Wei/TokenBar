# Data Source

TokenBar intentionally supports one source: Codex.

| Data | Source | Freshness | Confidence |
| --- | --- | --- | --- |
| 5-hour quota | `account/rateLimits/read` | Live | High |
| 7-day quota | `account/rateLimits/read` | Live | High |
| Independent quota buckets | `rateLimitsByLimitId` | Live | High |
| Plan, credits, reset credits, limit reason | Codex app-server response | Live | High |
| Rolling change signal | `account/rateLimits/updated` | Live | High |

The backward-compatible `rateLimits` field remains supported for older Codex CLI versions. TokenBar does not estimate subscription quota from local token logs.

## Installation sources

| Source | Discovery | Validation |
| --- | --- | --- |
| Current ChatGPT/Codex app | Launch Services and known Applications paths | Bundle load, known bundled path, executable check, `codex --version` |
| User-selected `.app` | Finder picker | Same checks; ChatGPT Classic is rejected |
| Standalone Codex CLI | Common paths, `PATH`, or advanced Finder picker | Executable check and bounded `codex --version` |
