#!/bin/bash
set -euo pipefail
SCRIPT_DIR=$(dirname $(readlink -f $0))

# Checks upstream hatoo/oha for a newer release than the version pinned in
# download-oha-release.sh. When one exists, bumps the pin and re-vendors the
# binaries (with sha256 verification against the upstream release assets).
#
# Prints "changed=true" or "changed=false" for CI consumption.

DOWNLOAD_SCRIPT="${SCRIPT_DIR}/download-oha-release.sh"

github_api() {
    local url="$1"
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl -sf -H "Authorization: Bearer ${GITHUB_TOKEN}" "$url"
    else
        curl -sf "$url"
    fi
}

current_version=$(grep -E '^OHA_VERSION=' "$DOWNLOAD_SCRIPT" | cut -d'"' -f2)

latest_tag=$(github_api "https://api.github.com/repos/hatoo/oha/releases/latest" | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])')
latest_version="${latest_tag#v}"

echo "Pinned oha version:   ${current_version}" >&2
echo "Latest upstream tag:  ${latest_tag}" >&2

if [[ "$current_version" == "$latest_version" ]]; then
    echo "changed=false"
    exit 0
fi

sed -i.bak "s/^OHA_VERSION=\"${current_version}\"/OHA_VERSION=\"${latest_version}\"/" "$DOWNLOAD_SCRIPT"
rm -f "${DOWNLOAD_SCRIPT}.bak"

"$DOWNLOAD_SCRIPT"

echo "changed=true"
