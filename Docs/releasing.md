# Releasing TokenBar

TokenBar publishes source and release assets from the same GitHub repository.

## Automated Release

1. Update `VERSION`, `CHANGELOG.md`, and `Distribution/RELEASE_NOTES.md`.
2. Run the local verification commands below.
3. Commit and push the change to `main`.
4. Push a matching tag, such as `v0.2.0`.
5. The `Release` workflow tests, builds, verifies, and uploads `TokenBar.dmg` plus `SHA256SUMS`.

## Local Release

Maintainers can run:

```bash
Scripts/release.sh
```

This requires a clean worktree and an authenticated GitHub CLI session.

## Verification

```bash
swift test
swift build -c release -Xswiftc -warnings-as-errors
Scripts/package-dmg.sh
hdiutil verify dist/TokenBar.dmg
(cd dist && shasum -a 256 -c SHA256SUMS)
codesign --verify --deep --strict --verbose=2 dist/TokenBar.app
lipo dist/TokenBar.app/Contents/MacOS/TokenBar -verify_arch x86_64 arm64
```
