#!/usr/bin/env bash
set -euo pipefail

# Fetches the latest SurrealDB version and adds it to versions.json.
# Usage:
#   ./update.sh          # add latest version
#   ./update.sh 3.0.2    # add a specific version

VERSIONS_FILE="$(dirname "$0")/versions.json"

if [[ "${1:-}" != "" ]]; then
  VERSION="$1"
else
  VERSION=$(curl -sf https://download.surrealdb.com/latest.txt | sed 's/^v//')
  echo "Latest version: $VERSION"
fi

if jq -e ".versions[\"$VERSION\"]" "$VERSIONS_FILE" > /dev/null 2>&1; then
  echo "Version $VERSION already in versions.json"
  exit 0
fi

declare -A ARCH_MAP=(
  [x86_64-linux]=linux-amd64
  [aarch64-linux]=linux-arm64
  [x86_64-darwin]=darwin-amd64
  [aarch64-darwin]=darwin-arm64
)

echo "Fetching hashes for v$VERSION..."
ENTRY="{}"
for system in "${!ARCH_MAP[@]}"; do
  arch="${ARCH_MAP[$system]}"
  url="https://download.surrealdb.com/v${VERSION}/surreal-v${VERSION}.${arch}.tgz"
  echo "  $system ($arch)..."
  hash=$(nix hash convert --to sri --hash-algo sha256 $(curl -sfL "$url" | sha256sum | cut -d' ' -f1))
  ENTRY=$(echo "$ENTRY" | jq --arg s "$system" --arg h "$hash" '. + {($s): $h}')
done

jq --arg v "$VERSION" --argjson e "$ENTRY" '
  .latest = $v |
  .versions[$v] = $e
' "$VERSIONS_FILE" > "$VERSIONS_FILE.tmp" && mv "$VERSIONS_FILE.tmp" "$VERSIONS_FILE"

echo "Updated versions.json with v$VERSION"
