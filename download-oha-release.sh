#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Single source of truth for the vendored upstream version. The sync-oha.sh
# script bumps this pin; CI verifies the committed binaries against it.
OHA_VERSION="1.15.0"

DEST_DIR="${SCRIPT_DIR}/bin"

# Upstream release assets are raw binaries named by platform. Each entry maps
# an upstream asset name to the Rust target triple used by the launcher script.
OHA_ASSETS=(
    "oha-linux-amd64:x86_64-unknown-linux-musl"
    "oha-linux-arm64:aarch64-unknown-linux-musl"
    "oha-macos-arm64:aarch64-apple-darwin"
)

MODE="download"
if [[ "${1:-}" == "--verify-only" ]]; then
    MODE="verify"
fi

github_api() {
    local url="$1"
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl -sf -H "Authorization: Bearer ${GITHUB_TOKEN}" "$url"
    else
        curl -sf "$url"
    fi
}

sha256_of() {
    local file="$1"
    if command -v sha256sum > /dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
}

# Fetch the upstream release's asset digests once (name<space>sha256 per line).
fetch_digests() {
    local release_json
    if ! release_json=$(github_api "https://api.github.com/repos/hatoo/oha/releases/tags/v${OHA_VERSION}"); then
        echo ""
        return
    fi

    echo "$release_json" | python3 -c '
import json, sys
release = json.load(sys.stdin)
for asset in release.get("assets", []):
    digest = (asset.get("digest") or "").removeprefix("sha256:")
    if digest:
        print(asset["name"], digest)
'
}

DIGESTS=$(fetch_digests || true)

# Fail closed: without upstream digests the binaries cannot be verified, so
# neither downloading nor verification may report success.
if [[ -z "$DIGESTS" ]]; then
    echo "ERROR: could not fetch sha256 digests for oha v${OHA_VERSION} from the GitHub API." >&2
    echo "Refusing to continue — binaries cannot be verified without them." >&2
    exit 1
fi

digest_for() {
    local asset="$1"
    echo "$DIGESTS" | awk -v name="$asset" '$1 == name {print $2}'
}

FAILED=0

for entry in "${OHA_ASSETS[@]}"; do
    asset="${entry%%:*}"
    triple="${entry##*:}"
    target="$DEST_DIR/oha_${triple}"

    if [[ "$MODE" == "download" ]]; then
        curl -L -o "$target" \
            "https://github.com/hatoo/oha/releases/download/v${OHA_VERSION}/${asset}"
        chmod +x "$target"
    fi

    if [[ ! -f "$target" ]]; then
        echo "MISSING  ${target}" >&2
        FAILED=1
        continue
    fi

    expected=$(digest_for "$asset")
    if [[ -z "$expected" ]]; then
        echo "MISSING DIGEST ${asset}: upstream release publishes no sha256 digest for this asset" >&2
        FAILED=1
        continue
    fi

    actual=$(sha256_of "$target")
    if [[ "$actual" == "$expected" ]]; then
        echo "OK       ${asset} -> oha_${triple} (sha256 verified)"
    else
        echo "MISMATCH ${asset}: expected ${expected}, got ${actual}" >&2
        FAILED=1
    fi
done

if [[ "$FAILED" -ne 0 ]]; then
    echo "Binary verification failed for oha v${OHA_VERSION}." >&2
    exit 1
fi

echo "All binaries match upstream oha v${OHA_VERSION}."
