#!/usr/bin/env bash
# Add CrowdSec to an existing Pangolin installation with the official
# installer's --crowdsec pass, then change three of its defaults. Runs on the
# server as your admin user (in the docker group, with sudo).
#
#   ./install-crowdsec.sh
#
# The installer skips CrowdSec on a first install, so this is a second run. It
# refuses to start while ports 80 and 443 are in use, so the script stops the
# stack first; the installer starts it again.
#
# The three changes, each checked before and after:
#   - profiles.yaml: web attacks get a ban instead of a captcha (no captcha
#     service is configured, so the captcha never shows);
#   - traefik_config.yml: remove minDuration: 100ms, which kept fast requests
#     out of the access log CrowdSec reads;
#   - dynamic_config.yml: remove forwardedHeadersTrustedIPs: 0.0.0.0/0, which
#     let any client fake its address in X-Forwarded-For.
#
# Afterwards the apps behind Pangolin depend on CrowdSec: if the crowdsec
# container stops, Traefik blocks requests. It fails closed.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

version="${PANGOLIN_VERSION:-$PANGOLIN_VERSION_DEFAULT}"
expected_sha="${PANGOLIN_INSTALLER_SHA256:-$PANGOLIN_INSTALLER_SHA256_DEFAULT}"
[[ "$version" == "$PANGOLIN_VERSION_DEFAULT" ]] \
  || die "PANGOLIN_VERSION=$version is not the tested release ($PANGOLIN_VERSION_DEFAULT)."

profiles="$PANGOLIN_DIR/config/crowdsec/profiles.yaml"
traefik_static="$PANGOLIN_DIR/config/traefik/traefik_config.yml"
traefik_dynamic="$PANGOLIN_DIR/config/traefik/dynamic_config.yml"

[[ -e "$PANGOLIN_DIR/config/config.yml" ]] \
  || die "No Pangolin installation in $PANGOLIN_DIR. Run install-pangolin.sh first."
[[ "$(id -u)" -ne 0 ]] || die "Run as your admin user, not root."
docker info > /dev/null 2>&1 || die "docker does not work for $(id -un); log out and back in after install-docker.sh."

installed=0
grep -Eq '^[[:space:]]+crowdsec:[[:space:]]*$' "$PANGOLIN_DIR/docker-compose.yml" && installed=1

if [[ $installed -eq 0 ]]; then
  installer="$(fetch_installer "$version" "$expected_sha")"

  info "Checking sudo (it may ask for your password once)"
  sudo true

  info "Stopping the stack; the installer needs ports 80 and 443 free"
  (cd "$PANGOLIN_DIR" && docker compose down)

  log="$INSTALLER_DIR/crowdsec.log"
  info "Running Pangolin's installer with --crowdsec; its output goes to $log"
  # Questions of release 1.24.0 for an existing installation in the working
  # directory. The MaxMind question depends on whether the databases exist.
  rc=0
  run_answered "$log" "$PANGOLIN_DIR" \
    "the MaxMind (GeoLite2 )?databases|n" \
    "Would you like to install CrowdSec\?|y" \
    "Are you willing to manage CrowdSec\?|y" \
    "Are these values correct\?|y" \
    -- "$installer" --crowdsec || rc=$?

  if [[ $rc -ne 0 ]] || ! grep -q "CrowdSec installed successfully" "$log"; then
    echo "---- last lines of $log ----" >&2
    log_tail "$log" >&2
    echo "The stack may still be stopped. After reading the log, start it again with:" >&2
    echo "  cd $PANGOLIN_DIR && docker compose up -d" >&2
    die "The CrowdSec pass did not finish (status $rc)."
  fi
  rm -f "$log"
  info "CrowdSec added"
else
  info "CrowdSec is already in docker-compose.yml; only checking the three defaults"
fi

for f in "$profiles" "$traefik_static" "$traefik_dynamic"; do
  [[ -r "$f" ]] || die "Cannot read $f as $(id -un)."
done

CHANGED=0
profiles_use_ban "$profiles"
info "profiles.yaml: ban, no captcha"
access_log_keeps_fast_requests "$traefik_static"
info "traefik_config.yml: no minDuration filter on the access log"
forwarded_headers_trusted_from_nobody "$traefik_dynamic"
info "dynamic_config.yml: forwarded headers trusted from nobody"

if [[ $CHANGED -eq 1 || $installed -eq 0 ]]; then
  info "Restarting traefik and crowdsec"
  (cd "$PANGOLIN_DIR" && docker compose restart traefik crowdsec)
fi

info "Waiting for crowdsec to report healthy"
for _ in $(seq 1 40); do
  state="$(docker inspect -f '{{.State.Health.Status}}' crowdsec 2>/dev/null || true)"
  [[ "$state" == "healthy" ]] && break
  sleep 3
done
[[ "${state:-}" == "healthy" ]] || die "crowdsec is '${state:-missing}' after two minutes. Check: docker logs crowdsec"

echo
docker compose -f "$PANGOLIN_DIR/docker-compose.yml" ps
echo
info "CrowdSec is on, with the three defaults changed."
echo "Remember: if the crowdsec container stops, the apps behind Pangolin go offline with it."
echo "Next: run verify.sh here, then ban-test.sh on your workstation."
