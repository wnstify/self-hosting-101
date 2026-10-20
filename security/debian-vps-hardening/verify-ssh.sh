#!/usr/bin/env bash
# Check a hardened server from the workstation. Changes nothing.
#
#   ./verify-ssh.sh SERVER ADMIN_USER
#
# SERVER is the DNS name or IPv4 address you connect to. Uses your normal SSH
# configuration and known_hosts; it never turns host-key checking off.
# Expected result: three PASS lines and "All SSH checks passed."
set -uo pipefail

server="${1:-}"
admin="${2:-}"
if [[ -z "$server" || -z "$admin" ]]; then
  echo "Usage: verify-ssh.sh SERVER ADMIN_USER" >&2
  exit 2
fi

fail=0
pass() { echo "PASS $*"; }
miss() { echo "FAIL $*"; fail=1; }

# 1. The key logs in as the admin user, and sudo works.
out="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$admin@$server" 'sudo -n whoami' 2>&1)"
if [[ "$out" == *root* ]]; then
  pass "key login as $admin works and sudo returns root"
else
  miss "key login or sudo for $admin: $out"
fi

# 2. Root is refused, even with the right key.
out="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "root@$server" true 2>&1)"
if [[ "$out" == *"Permission denied"* ]]; then
  pass "root login is refused"
else
  miss "root login was not refused: $out"
fi

# 3. The server offers no password or keyboard-interactive login at all.
out="$(ssh -o BatchMode=yes -o ConnectTimeout=15 -o PubkeyAuthentication=no \
  -o PreferredAuthentications=password,keyboard-interactive "$admin@$server" true 2>&1)"
if [[ "$out" == *"Permission denied (publickey)"* ]]; then
  pass "password and keyboard-interactive logins are not offered"
else
  miss "the server still offers another method: $out"
fi

if [[ "$fail" -eq 0 ]]; then
  echo "All SSH checks passed."
else
  echo "Some SSH checks failed. Keep your existing session open and fix them first." >&2
  exit 1
fi
