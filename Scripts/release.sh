#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
REPOSITORY="${REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
TAG="v$VERSION"

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  echo "Release requires a clean worktree." >&2
  exit 2
fi

swift test --package-path "$ROOT_DIR"
RELEASE_BUILD=0 VERSION="$VERSION" "$ROOT_DIR/Scripts/package-dmg.sh"

if gh release view "$TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
  gh release upload "$TAG" \
    "$ROOT_DIR/dist/TokenBar.dmg#TokenBar.dmg" \
    "$ROOT_DIR/dist/SHA256SUMS#SHA256SUMS" \
    --repo "$REPOSITORY" \
    --clobber
  gh release edit "$TAG" \
    --repo "$REPOSITORY" \
    --title "TokenBar $VERSION" \
    --notes-file "$ROOT_DIR/Distribution/RELEASE_NOTES.md"
else
  gh release create "$TAG" \
    "$ROOT_DIR/dist/TokenBar.dmg#TokenBar.dmg" \
    "$ROOT_DIR/dist/SHA256SUMS#SHA256SUMS" \
    --repo "$REPOSITORY" \
    --target main \
    --title "TokenBar $VERSION" \
    --notes-file "$ROOT_DIR/Distribution/RELEASE_NOTES.md"
fi

echo "Published https://github.com/$REPOSITORY/releases/tag/$TAG"
