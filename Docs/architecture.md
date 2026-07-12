# Architecture

TokenBar has three targets:

- `TokenBarCore`: Codex protocol models, parser, storage, quota policy, and tests.
- `TokenBarApp`: AppKit/SwiftUI menu bar app, settings, notifications, hotkey, and installer.
- `TokenBarCLI`: local diagnostics for the same Codex provider.

## Data flow

1. `CodexAppServerClient` starts one `codex app-server --stdio` child process for the app session.
2. The client initializes structured JSON-RPC with `experimentalApi` enabled.
3. `CodexProvider` calls `account/rateLimits/read` and prefers `rateLimitsByLimitId` while retaining the legacy `rateLimits` fallback.
4. `account/rateLimits/updated` triggers a coalesced snapshot refresh.
5. `CodexRateLimitParser` normalizes official windows into `QuotaSnapshot` values.
6. The app model publishes one Codex update to the menu bar, popover, and notification policy.
7. The popover derives its height from the normalized window count and adds scrolling only above the visible-window limit.
8. A persisted `QuotaSelection` matches the selected limit by quota label and window label. Missing selections fall back to the preferred seven-day snapshot.

Before the provider starts, `CodexInstallationResolver` validates the configured source. Automatic mode checks Launch Services for `com.openai.codex`, known ChatGPT/Codex application locations, common standalone CLI paths, and then `PATH`. App selections resolve only the known `Contents/Resources/codex` executable and reject ChatGPT Classic (`com.openai.chat`). Every candidate must pass a bounded `--version` check before app-server startup.

Quota progress colors are stored as two sRGB endpoints. `QuotaColorConfiguration` converts them to linear light, interpolates by remaining percentage, and converts the result back to sRGB. This keeps user-selected gradients visually even while all non-progress UI retains the fixed Codex palette.

The app-server process is terminated on shutdown, timeout, or connection failure. The next refresh reconnects automatically.

## Storage

Settings are atomically stored at:

```text
~/Library/Application Support/TokenBar/settings.json
```

Legacy multi-provider fields are ignored during decoding and disappear after the next save. Legacy Codex executable paths migrate into automatic, application, or custom-executable source modes. TokenBar stores no provider credentials.
Appearance settings contain only the two user-selected RGB endpoint colors. The selected menu-bar quota stores only its public quota/window labels; no account data is added.

The language field stores only `en` or `zh-Hans`. Missing legacy language values always migrate to English. `TokenBarStrings` is shared by Core, App, and CLI so runtime language switching also rebuilds provider details and notifications.

## Distribution

The public source repository builds a universal custom DMG, generates `SHA256SUMS`, verifies the application bundle, and attaches the release assets to the matching GitHub Release.
