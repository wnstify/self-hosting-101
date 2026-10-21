#!/usr/bin/env bash
# Read-only checks before installing NetBird. Runs on the server. Changes nothing.
#
#   NETBIRD_DOMAIN=netbird.example.com ./preflight.sh
#
# Set REQUIRE_DOCKER=1 to fail when Docker, Compose, jq or curl are missing
# (install-netbird.sh does this). Expected result: no FAIL lines and
# "Preflight passed."
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

fails=0
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; fails=$((fails + 1)); }
note() { echo "NOTE $*"; }

domain="${NETBIRD_DOMAIN:-}"

# Operating system and hardware.
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "13" ]]; then
    pass "Debian 13"
  else
    fail "tested on Debian 13 only (found ${ID:-unknown} ${VERSION_ID:-unknown})"
  fi
else
  fail "/etc/os-release is missing"
fi

arch="$(uname -m)"
if [[ "$arch" == "x86_64" ]]; then pass "architecture x86_64"; else fail "tested on x86_64 only (found $arch)"; fi

mem_mb="$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)"
if [[ "$mem_mb" -ge 1800 ]]; then pass "memory ${mem_mb} MB"; else fail "memory ${mem_mb} MB, NetBird needs about 2 GB"; fi

disk_gb="$(df -Pk / | awk 'NR == 2 {print int($4 / 1048576)}')"
if [[ "$disk_gb" -ge 10 ]]; then pass "free disk ${disk_gb} GB"; else fail "free disk ${disk_gb} GB, keep at least 10 GB"; fi

# This server is meant to run NetBird and nothing else.
if [[ "$(id -u)" -eq 0 ]]; then
  fail "running as root; run as your admin user (the hardening guide creates it)"
else
  pass "running as $(id -un)"
fi

# Domain and DNS.
if [[ -z "$domain" ]]; then
  fail "NETBIRD_DOMAIN is not set"
elif ! valid_fqdn "$domain"; then
  fail "'$domain' is not a valid name; use something like netbird.your-domain.com"
elif reserved_domain "$domain"; then
  fail "'$domain' is a documentation name; use your own domain"
else
  pass "domain $domain"
  ip4="$(public_ipv4)"
  addrs="$(resolved_ipv4s "$domain" | tr '\n' ' ')"
  if [[ -z "$ip4" ]]; then
    fail "could not read this server's public IPv4 address; set PUBLIC_IPV4"
  elif [[ -z "$addrs" ]]; then
    fail "$domain does not resolve yet; add the A record and wait for DNS"
  elif [[ " $addrs " == *" $ip4 "* && "$(echo "$addrs" | wc -w)" -eq 1 ]]; then
    pass "$domain resolves to this server ($ip4)"
  else
    fail "$domain resolves to '$addrs', this server is $ip4 (with Cloudflare, set the record to DNS only)"
  fi
fi

# Ports NetBird needs must be free, unless NetBird already runs here.
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx netbird-server; then
  note "NetBird already runs here; skipping the free-port checks"
else
  busy=""
  ss -Hltn 2>/dev/null | awk '{print $4}' | grep -Eq '[:.](80|443)$' && busy="$busy 80-or-443/tcp"
  ss -Hlun 2>/dev/null | awk '{print $4}' | grep -Eq '[:.]3478$' && busy="$busy 3478/udp"
  if [[ -z "$busy" ]]; then pass "ports 80/tcp, 443/tcp, 3478/udp are free"; else fail "already in use:$busy; this server should run NetBird only"; fi
fi

# Host firewall, when ufw is active.
if command -v ufw > /dev/null 2>&1 && sudo -n ufw status 2>/dev/null | grep -q '^Status: active'; then
  rules="$(sudo -n ufw status)"
  missing=""
  for p in 22/tcp 80/tcp 443/tcp 3478/udp; do
    echo "$rules" | grep -Eq "^$p" || missing="$missing $p"
  done
  if [[ -z "$missing" ]]; then pass "ufw allows 22, 80, 443 and 3478/udp"; else fail "ufw is missing:$missing"; fi
else
  note "ufw is not active or not readable without a password; check your provider firewall allows 80/tcp, 443/tcp and 3478/udp"
fi

# Tools the installer needs.
missing_tools=""
for t in docker jq curl; do
  command -v "$t" > /dev/null 2>&1 || missing_tools="$missing_tools $t"
done
docker compose version > /dev/null 2>&1 || missing_tools="$missing_tools docker-compose-plugin"
if [[ -z "$missing_tools" ]]; then
  pass "docker, compose, jq and curl are installed"
  if docker info > /dev/null 2>&1; then
    pass "docker works for $(id -un)"
  elif [[ "${REQUIRE_DOCKER:-0}" == "1" ]]; then
    fail "docker is installed but $(id -un) cannot use it; log out and back in after install-docker.sh"
  else
    note "docker works only after you log out and back in"
  fi
elif [[ "${REQUIRE_DOCKER:-0}" == "1" ]]; then
  fail "missing:$missing_tools; run install-docker.sh"
else
  note "missing:$missing_tools; install-docker.sh installs them"
fi

if [[ "$fails" -eq 0 ]]; then
  echo "Preflight passed."
else
  echo "Preflight failed with $fails problem(s). Nothing was changed."
  exit 1
fi
