#!/usr/bin/env bash
set -euo pipefail

# Manages versions.json for the SurrealDB Nix flake.
# Usage:
#   ./update.sh          # add latest version and set it as latest
#   ./update.sh 3.0.2    # add a specific version (does not update latest)
#   ./update.sh --all    # add all stable releases from GitHub (does not update latest)

VERSIONS_FILE="$(dirname "$0")/versions.json"
PARALLELISM=8

declare -A ARCH_MAP=(
  [x86_64-linux]=linux-amd64
  [aarch64-linux]=linux-arm64
  [x86_64-darwin]=darwin-amd64
  [aarch64-darwin]=darwin-arm64
)

hash_one() {
  local version="$1" system="$2" arch="$3"
  local url="https://download.surrealdb.com/v${version}/surreal-v${version}.${arch}.tgz"
  local raw
  raw=$(curl -sfL "$url" | sha256sum | cut -d' ' -f1)
  nix hash convert --to sri --hash-algo sha256 "$raw"
}

add_version() {
  local version="$1"
  local versions_file="$2"
  local update_latest="${3:-false}"

  if jq -e ".versions[\"$version\"]" "$versions_file" > /dev/null 2>&1; then
    return 0
  fi

  echo "Fetching hashes for v$version..."

  local tmpdir
  tmpdir=$(mktemp -d)

  for system in "${!ARCH_MAP[@]}"; do
    local arch="${ARCH_MAP[$system]}"
    (
      hash=$(hash_one "$version" "$system" "$arch")
      echo "$hash" > "$tmpdir/$system"
    ) &
  done
  wait

  local entry="{}"
  for system in "${!ARCH_MAP[@]}"; do
    local hash
    hash=$(cat "$tmpdir/$system")
    entry=$(echo "$entry" | jq --arg s "$system" --arg h "$hash" '. + {($s): $h}')
  done

  if [[ "$update_latest" == "true" ]]; then
    jq --arg v "$version" --argjson e "$entry" '
      .latest = $v | .versions[$v] = $e
    ' "$versions_file" > "$versions_file.tmp" && mv "$versions_file.tmp" "$versions_file"
  else
    jq --arg v "$version" --argjson e "$entry" '
      .versions[$v] = $e
    ' "$versions_file" > "$versions_file.tmp" && mv "$versions_file.tmp" "$versions_file"
  fi

  rm -rf "$tmpdir"
  echo "  Added v$version"
}

fetch_all_stable_versions() {
  local page=1 versions=()
  while true; do
    local batch
    batch=$(curl -sf "https://api.github.com/repos/surrealdb/surrealdb/releases?per_page=100&page=$page" \
      | jq -r '[.[] | select(.prerelease == false and .draft == false) | .tag_name | ltrimstr("v") | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))] | .[]')
    if [[ -z "$batch" ]]; then
      break
    fi
    while IFS= read -r v; do
      versions+=("$v")
    done <<< "$batch"
    ((page++))
  done
  printf '%s\n' "${versions[@]}"
}

if [[ "${1:-}" == "--all" ]]; then
  echo "Fetching all stable releases from GitHub..."
  all_versions=$(fetch_all_stable_versions)
  total=$(echo "$all_versions" | wc -l)
  echo "Found $total stable versions"

  count=0
  while IFS= read -r version; do
    count=$((count + 1))
    if jq -e ".versions[\"$version\"]" "$VERSIONS_FILE" > /dev/null 2>&1; then
      echo "[$count/$total] v$version — already present"
      continue
    fi
    echo "[$count/$total] v$version — fetching..."
    add_version "$version" "$VERSIONS_FILE" "false"
  done <<< "$all_versions"

  echo "Done. $(jq '.versions | keys | length' "$VERSIONS_FILE") versions in versions.json"

elif [[ "${1:-}" != "" ]]; then
  add_version "$1" "$VERSIONS_FILE" "false"

else
  VERSION=$(curl -sf https://download.surrealdb.com/latest.txt | sed 's/^v//')
  echo "Latest version: $VERSION"
  add_version "$VERSION" "$VERSIONS_FILE" "true"
fi
