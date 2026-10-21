#!/usr/bin/env bash
# Install Pangolin with its official installer, pinned to a tested release and
# checked against its SHA-256 before it runs. Runs on the server as your admin
# user (in the docker group, with sudo).
#
#   PANGOLIN_DOMAIN=pangolin.your-domain.com \
#   PANGOLIN_LETSENCRYPT_EMAIL=you@your-domain.com \
#   ./install-pangolin.sh
#
# Result: Pangolin Community Edition, Gerbil and Traefik in /opt/pangolin,
# owned by you, with PANGOLIN_DOMAIN as both the base domain and the dashboard,
# SQLite, no SMTP, IPv4 only, MaxMind databases downloaded. The script refuses
# to touch an existing installation. CrowdSec is a second step:
# install-crowdsec.sh.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

domain="${PANGOLIN_DOMAIN:-}"
email="${PANGOLIN_LETSENCRYPT_EMAIL:-}"
version="${PANGOLIN_VERSION:-$PANGOLIN_VERSION_DEFAULT}"
expected_sha="${PANGOLIN_INSTALLER_SHA256:-$PANGOLIN_INSTALLER_SHA256_DEFAULT}"

if [[ "$version" != "$PANGOLIN_VERSION_DEFAULT" ]]; then
  die "PANGOLIN_VERSION=$version is not the tested release ($PANGOLIN_VERSION_DEFAULT). Its questions may differ from the answers this script gives."
fi

valid_fqdn "$domain" && ! reserved_domain "$domain" \
  || die "PANGOLIN_DOMAIN must be your own name, such as pangolin.your-domain.com (got '$domain')."

valid_email "$email" \
  || die "PANGOLIN_LETSENCRYPT_EMAIL must be an address on a real domain (got '$email'). Let's Encrypt refuses placeholders such as example.com."

info "Preflight"
PANGOLIN_DOMAIN="$domain" REQUIRE_DOCKER=1 "$here/preflight.sh" || die "Fix the preflight failures first."

if [[ -e "$PANGOLIN_DIR/config/config.yml" || -e "$PANGOLIN_DIR/docker-compose.yml" ]]; then
  die "$PANGOLIN_DIR already holds a Pangolin installation. Updates are in the guide's Maintenance section; this script never reinstalls."
fi

installer="$(fetch_installer "$version" "$expected_sha")"

info "Checking sudo (it may ask for your password once)"
sudo true

log="$INSTALLER_DIR/install.log"
info "Running Pangolin's installer; its output goes to $log"
# Questions of release 1.24.0, in order, for a fresh install run with sudo from
# a directory that holds no installation.
rc=0
run_answered "$log" "$INSTALLER_DIR" \
  "Enter the installation directory|" \
  "?does not exist\. Create it\?|y" \
  "?change ownership of|y" \
  "install the Enterprise version|n" \
  "use PostgreSQL|n" \
  "Enter your base domain|$domain" \
  "domain for the Pangolin dashboard|$domain" \
  "email for Let's Encrypt|$email" \
  "use Gerbil to allow tunneled|y" \
  "Enable email functionality|n" \
  "server IPv6 capable|n" \
  "GeoLite2 Country and ASN databases for blocking|y" \
  "install and start the containers|y" \
  "Docker or Podman|" \
  -- "$installer" || rc=$?

if [[ $rc -ne 0 ]]; then
  echo "---- last lines of $log ----" >&2
  log_tail "$log" >&2
  case $rc in
    2) die "The installer stopped before all questions were answered. Read the log; do not rerun over a half-made $PANGOLIN_DIR without checking it." ;;
    3) die "The installer asked something this script does not expect, or hung. It was stopped. Read the log." ;;
    *) die "The installer exited with status $rc. Read the log." ;;
  esac
fi

grep -q "SETUP TOKEN" "$log" || no_setup_notice=1
rm -f "$log"

echo
info "Installed in $PANGOLIN_DIR."
docker compose -f "$PANGOLIN_DIR/docker-compose.yml" ps
echo
echo "Next:"
echo "  1. Read the one-time setup token yourself:"
echo "       docker logs pangolin 2>&1 | grep -A 3 'SETUP TOKEN'"
echo "  2. Open https://$domain/auth/initial-setup in your browser, paste it, and create the admin account."
echo "  3. Then run install-crowdsec.sh, or verify.sh if you skip CrowdSec."
if [[ "${no_setup_notice:-0}" == "1" ]]; then
  echo "NOTE the installer did not print a setup token; the pangolin container may still be starting. Rerun the command in step 1 in a minute."
fi
