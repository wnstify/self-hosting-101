#!/usr/bin/env bash
# Shared checks for the self-hosted NetBird scripts. Sourced, not run.

# Tested release. Change these together, and only after a live test.
NETBIRD_VERSION_DEFAULT="v0.81.3"
NETBIRD_INSTALLER_SHA256_DEFAULT="0aee21c20f9731293bec6b0d1fc73cbbca29f03ef626636ed9d0c7d8261c92fc"
NETBIRD_SERVER_IMAGE_DEFAULT="netbirdio/netbird-server:0.81.3"
DASHBOARD_IMAGE_DEFAULT="netbirdio/dashboard:v2.95.0"
TRAEFIK_IMAGE_DEFAULT="traefik:v3.7.14"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

# Same shape the NetBird installer accepts: labels of letters, digits and
# hyphens, at least one dot, no scheme, port or trailing dot.
valid_fqdn() {
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]]
}

# Documentation and special-use names (RFC 2606, RFC 6761) that can never get
# a public certificate. Let's Encrypt also refuses them as contact addresses.
reserved_domain() {
  local d
  d="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$d" in
    example.com|*.example.com|example.net|*.example.net|example.org|*.example.org) return 0 ;;
    example|*.example|test|*.test|invalid|*.invalid|localhost|*.localhost|local|*.local) return 0 ;;
  esac
  return 1
}

valid_email() {
  local e="$1" domain
  [[ "$e" =~ ^[^@[:space:]]+@[^@[:space:]]+$ ]] || return 1
  domain="${e#*@}"
  valid_fqdn "$domain" || return 1
  reserved_domain "$domain" && return 1
  return 0
}

# This server's public IPv4 address: the source address of the default route.
# Set PUBLIC_IPV4 to override (for example behind 1:1 NAT).
public_ipv4() {
  if [[ -n "${PUBLIC_IPV4:-}" ]]; then
    echo "$PUBLIC_IPV4"
    return 0
  fi
  ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") {print $(i + 1); exit}}'
}

# Every IPv4 address the name resolves to, one per line.
resolved_ipv4s() {
  getent ahostsv4 "$1" 2>/dev/null | awk '{print $1}' | sort -u
}

sha256_of() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
