# Contributing

## Principles

- Keep TokenBar focused on Codex quota visibility.
- Use documented Codex app-server methods and generated schemas.
- Never read auth files, browser state, prompts, or source code.
- Keep the menu bar experience compact and native.
- Add fixture or protocol tests for every parser and transport change.
- Add both English and Simplified Chinese strings for every user-facing message.

## Development

```bash
swift test
swift run TokenBarApp
swift run tokenbar refresh
```

UI smoke-test launch arguments:

```bash
swift run TokenBarApp --show-popover
swift run TokenBarApp --show-settings
```

Before submitting a change:

```bash
swift test
swift build -c release
git diff --check
```
