# Contributing to TokenBar

Thanks for helping improve TokenBar. Contributions should keep the product focused, local-first, and safe to distribute.

## Before You Start

- Search existing issues before opening a new one.
- Use an issue for behavior changes or larger proposals.
- Never include account tokens, cookies, `auth.json`, prompts, source code from user sessions, or private API responses.
- Keep user-facing text available in both English and Simplified Chinese.

## Development

Requirements: macOS 14+, Swift 6.2+, and the current ChatGPT/Codex app or Codex CLI.

```bash
git clone https://github.com/Eddiee-Wei/TokenBar.git
cd TokenBar
swift test
swift run TokenBarApp
```

Useful smoke-test launches:

```bash
swift run TokenBarApp --show-popover
swift run TokenBarApp --show-settings
swift run tokenbar refresh
```

## Pull Requests

1. Create a focused branch from `main`.
2. Keep unrelated formatting or refactors out of the change.
3. Add tests for parser, storage, resolver, or transport behavior.
4. Run the checks below.
5. Explain user impact, privacy impact, and verification in the pull request.

```bash
swift test
swift build -c release -Xswiftc -warnings-as-errors
git diff --check
```

By contributing, you agree that your contribution is licensed under the MIT License in this repository.

## Reporting Security Issues

Do not open a public issue for a vulnerability. Follow [SECURITY.md](SECURITY.md).
