#!/usr/bin/env bash
# Bump the plugin version everywhere it is written down.
#
# One place today — lua/dedalo/version.lua — and this script exists anyway,
# because "one place" is a fact that stops being true quietly. The Version
# workflow calls it; nothing else should.
#
# Usage:
#   scripts/bump-version.sh patch|minor|major|<explicit-version> [--dry-run]
#
# Prints the new version on stdout and nothing else, so callers can capture it.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION_FILE="lua/dedalo/version.lua"

level="${1:-}"
dry_run="${2:-}"

if [ -z "$level" ]; then
  echo "usage: $0 patch|minor|major|<version> [--dry-run]" >&2
  exit 2
fi

current=$(grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' "$VERSION_FILE" | head -1 | tr -d '"')
if [ -z "$current" ]; then
  echo "cannot read a semver version from $VERSION_FILE" >&2
  exit 1
fi

IFS='.' read -r major minor patch <<< "$current"

case "$level" in
  major) next="$((major + 1)).0.0" ;;
  minor) next="$major.$((minor + 1)).0" ;;
  patch) next="$major.$minor.$((patch + 1))" ;;
  *)
    if ! printf '%s' "$level" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
      echo "'$level' is neither a bump level nor a semver version" >&2
      exit 2
    fi
    next="$level"
    ;;
esac

if [ "$next" = "$current" ]; then
  echo "version is already $next" >&2
  exit 1
fi

if [ "$dry_run" = "--dry-run" ]; then
  printf '%s\n' "$next"
  exit 0
fi

sed -i.bak -E "s/\"$current\"/\"$next\"/" "$VERSION_FILE"
rm -f "$VERSION_FILE.bak"

if ! grep -q "\"$next\"" "$VERSION_FILE"; then
  echo "the version line did not change to $next" >&2
  exit 1
fi

printf '%s\n' "$next"
