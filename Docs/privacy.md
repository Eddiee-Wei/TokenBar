# Privacy

TokenBar is local-only by design.

It does not:

- upload quota data or analytics;
- read source code or prompts;
- read `~/.codex/auth.json`;
- read browser cookies;
- scrape ChatGPT or Codex websites;
- include third-party analytics SDKs.

TokenBar starts the installed Codex CLI's official local app-server process and reads only quota snapshots returned by `account/rateLimits/read`. Opening the official usage page is an explicit user action handled by macOS.

Local settings contain language, refresh, notification, launch-at-login, selected quota, colors, Codex app/CLI location, timeout, and hotkey preferences. The saved app path and bundle identifier are used only to reconnect after an app update or move. Settings contain no account credentials.
