## Summary

Describe what changed and why.

## User Impact

Describe visible behavior changes, compatibility concerns, and migration needs.

## Privacy and Security

- [ ] No credentials, cookies, prompts, source code, or private account data are included.
- [ ] Executable discovery and external process changes are constrained and validated.
- [ ] New user-facing text is available in English and Simplified Chinese.

## Verification

- [ ] `swift test`
- [ ] `swift build -c release -Xswiftc -warnings-as-errors`
- [ ] `git diff --check`
- [ ] UI or DMG behavior was manually checked when relevant.
