#!/usr/bin/env bash
# Shared checks for the Debian VPS hardening scripts. Sourced, not run.

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

# A Linux user name this guide accepts: lowercase, starts with a letter,
# letters, digits, hyphen or underscore, at most 32 characters, not root.
valid_admin_user() {
  local name="$1"
  [[ -n "$name" && "$name" != "root" ]] || return 1
  [[ ${#name} -le 32 ]] || return 1
  [[ "$name" =~ ^[a-z][a-z0-9_-]*$ ]]
}

# Accept "any" or an IPv4 address or IPv4 CIDR for the SSH allow rule.
valid_ssh_source() {
  local src="$1" ip prefix octet
  [[ "$src" == "any" ]] && return 0
  ip="${src%/*}"
  if [[ "$src" == */* ]]; then
    prefix="${src#*/}"
    [[ "$prefix" =~ ^[0-9]+$ && "$prefix" -ge 8 && "$prefix" -le 32 ]] || return 1
  fi
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  local IFS=.
  for octet in $ip; do
    [[ "$octet" -le 255 ]] || return 1
  done
  return 0
}

# Ports for ufw: a space-separated list of PORT/tcp or PORT/udp entries.
valid_port_list() {
  local entry port
  for entry in $1; do
    [[ "$entry" =~ ^[0-9]+/(tcp|udp)$ ]] || return 1
    port="${entry%/*}"
    [[ "$port" -ge 1 && "$port" -le 65535 ]] || return 1
  done
  return 0
}

# True when the file holds at least one public key ssh-keygen can read.
has_valid_public_key() {
  local file="$1" line tmp found=1
  [[ -s "$file" ]] || return 1
  tmp="$(mktemp)"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    printf '%s\n' "$line" > "$tmp"
    if ssh-keygen -l -f "$tmp" > /dev/null 2>&1; then
      found=0
      break
    fi
  done < "$file"
  rm -f "$tmp"
  return "$found"
}
