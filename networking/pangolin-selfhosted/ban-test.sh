#!/usr/bin/env bash
# Prove CrowdSec blocks: ban your own public address for one minute, see your
# own site refuse you, lift the ban, and see it answer again. Runs on the
# WORKSTATION, not the server: a request the server makes to itself never
# comes from the banned address.
#
#   ./ban-test.sh alice@pangolin.your-domain.com pangolin.your-domain.com
#
# The address banned is the one the server sees for this SSH connection, so
# the test works behind home NAT. Private ranges are allowlisted by default
# and cannot be tested this way. All SSH commands share one connection, so a
# password-manager SSH agent asks for approval once. The ban is lifted on any
# exit, and expires after a minute anyway.
set -euo pipefail

target="${1:-}"
domain="${2:-}"
[[ -n "$target" && -n "$domain" ]] || { echo "usage: $0 USER@SERVER DOMAIN" >&2; exit 2; }

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

sock="$(mktemp -u "${TMPDIR:-/tmp}/ban-test.XXXXXX")"
ssh_run() { ssh -o ControlMaster=auto -o ControlPath="$sock" -o ControlPersist=120 "$target" "$@"; }

addr=""
banned=0
cleanup() {
  if [[ $banned -eq 1 && -n "$addr" ]]; then
    ssh_run docker exec crowdsec cscli decisions delete --ip "$addr" > /dev/null 2>&1 || true
  fi
  ssh -o ControlPath="$sock" -O exit "$target" > /dev/null 2>&1 || true
}
trap cleanup EXIT

status() { curl -s -o /dev/null -w '%{http_code}' --max-time 15 "https://$domain/" || true; }

addr="$(ssh_run 'echo "${SSH_CLIENT%% *}"')"
[[ "$addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Could not read the address the server sees for you (got '$addr'). The test needs IPv4."
case "$addr" in
  10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*)
    die "The server sees you from a private address. CrowdSec allowlists private ranges; run the test from the public internet." ;;
esac
info "The server sees you from your public address (not printed)"

code="$(status)"
[[ "$code" =~ ^(200|30[1278])$ ]] || die "https://$domain/ answers '$code' before the test; fix that first (verify.sh)."
info "Before the ban: $code"

# The bouncer caches a clean answer for about 15 seconds; wait it out.
sleep 20

ssh_run docker exec crowdsec cscli decisions add --ip "$addr" -d 1m --type ban > /dev/null
banned=1
info "Banned for one minute"

code=""
for _ in 1 2 3 4; do
  code="$(status)"
  [[ "$code" == "403" ]] && break
  sleep 5
done
[[ "$code" == "403" ]] || die "Still '$code' while banned. CrowdSec does not block this site."
info "While banned: 403"

ssh_run docker exec crowdsec cscli decisions delete --ip "$addr" > /dev/null
banned=0
info "Ban lifted"

# The bouncer may hold the ban in its cache for a few seconds more.
for _ in $(seq 1 12); do
  code="$(status)"
  [[ "$code" =~ ^(200|30[1278])$ ]] && break
  sleep 5
done
[[ "$code" =~ ^(200|30[1278])$ ]] || die "Still '$code' a minute after lifting the ban. Check: docker exec crowdsec cscli decisions list"
info "After the ban: $code"
echo "Ban test passed."
