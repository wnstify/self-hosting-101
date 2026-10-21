#!/usr/bin/env bash
# Install a self-hosted NetBird server with NetBird's official getting-started
# script, pinned to a tested release and checked against its SHA-256 before it
# runs. Runs on the server as your admin user (in the docker group).
#
#   NETBIRD_DOMAIN=netbird.your-domain.com \
#   NETBIRD_LETSENCRYPT_EMAIL=you@your-domain.com \
#   ./install-netbird.sh
#
# Result: built-in Traefik with Let's Encrypt, NetBird Proxy off, CrowdSec off,
# files in INSTALL_DIR (default ~/netbird). The script refuses to touch an
# existing installation.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

domain="${NETBIRD_DOMAIN:-}"
email="${NETBIRD_LETSENCRYPT_EMAIL:-}"
install_dir="${INSTALL_DIR:-$HOME/netbird}"
version="${NETBIRD_VERSION:-$NETBIRD_VERSION_DEFAULT}"
expected_sha="${NETBIRD_INSTALLER_SHA256:-$NETBIRD_INSTALLER_SHA256_DEFAULT}"

if [[ "$version" != "$NETBIRD_VERSION_DEFAULT" && -z "${NETBIRD_INSTALLER_SHA256:-}" ]]; then
  die "NETBIRD_VERSION=$version is not the tested release. Set NETBIRD_INSTALLER_SHA256 to the checksum you verified for it."
fi

valid_email "$email" \
  || die "NETBIRD_LETSENCRYPT_EMAIL must be an address on a real domain (got '$email'). Let's Encrypt refuses placeholders such as example.com."

info "Preflight"
NETBIRD_DOMAIN="$domain" REQUIRE_DOCKER=1 "$here/preflight.sh" || die "Fix the preflight failures first."

if [[ -e "$install_dir/config.yaml" || -e "$install_dir/docker-compose.yml" ]]; then
  die "$install_dir already holds a NetBird installation. Updates are in the guide's Maintenance section; this script never reinstalls."
fi
mkdir -p "$install_dir"
cd "$install_dir"

url="https://github.com/netbirdio/netbird/releases/download/${version}/getting-started.sh"
info "Downloading $url"
curl -fsSL "$url" -o getting-started.sh
actual_sha="$(sha256_of getting-started.sh)"
if [[ "$actual_sha" != "$expected_sha" ]]; then
  rm -f getting-started.sh
  die "Checksum mismatch for getting-started.sh (expected $expected_sha, got $actual_sha). Nothing was run."
fi
info "Checksum matches the tested release ($version)"

info "Running NetBird's installer (unattended)"
NETBIRD_DOMAIN="$domain" \
NETBIRD_LETSENCRYPT_EMAIL="$email" \
NETBIRD_REVERSE_PROXY_TYPE=0 \
NETBIRD_ENABLE_PROXY=false \
NETBIRD_ENABLE_CROWDSEC=false \
NETBIRD_NON_INTERACTIVE=true \
NETBIRD_SERVER_IMAGE="${NETBIRD_SERVER_IMAGE:-$NETBIRD_SERVER_IMAGE_DEFAULT}" \
DASHBOARD_IMAGE="${DASHBOARD_IMAGE:-$DASHBOARD_IMAGE_DEFAULT}" \
TRAEFIK_IMAGE="${TRAEFIK_IMAGE:-$TRAEFIK_IMAGE_DEFAULT}" \
  bash ./getting-started.sh

chmod 600 config.yaml 2>/dev/null || true
echo
info "Installed in $install_dir. Verify with:"
echo "  NETBIRD_DOMAIN=$domain INSTALL_DIR=$install_dir $here/verify.sh"
echo "Then open https://$domain in your browser and create the admin account yourself."
