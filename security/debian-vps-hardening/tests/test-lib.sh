#!/usr/bin/env bash
# Local checks for lib.sh. Touch no server. Run from the repository root:
#   bash security/debian-vps-hardening/tests/test-lib.sh
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib.sh
. "$here/lib.sh"

failures=0
expect() {
  local want="$1" desc="$2"; shift 2
  if "$@"; then got=ok; else got=refused; fi
  if [[ "$got" == "$want" ]]; then echo "PASS $desc"; else echo "FAIL $desc (wanted $want, got $got)"; failures=$((failures + 1)); fi
}

expect ok      "admin user alice"          valid_admin_user alice
expect ok      "admin user with digits"    valid_admin_user ops2
expect refused "admin user root"           valid_admin_user root
expect refused "admin user empty"          valid_admin_user ""
expect refused "admin user uppercase"      valid_admin_user Alice
expect refused "admin user with space"     valid_admin_user "a b"
expect refused "admin user starting digit" valid_admin_user 1ops

expect ok      "ssh source any"            valid_ssh_source any
expect ok      "ssh source single IPv4"    valid_ssh_source 192.0.2.10
expect ok      "ssh source CIDR"           valid_ssh_source 198.51.100.0/24
expect refused "ssh source bad octet"      valid_ssh_source 192.0.2.300
expect refused "ssh source /0"             valid_ssh_source 0.0.0.0/0
expect refused "ssh source hostname"       valid_ssh_source example.com
expect refused "ssh source IPv6"           valid_ssh_source 2001:db8::1

expect ok      "ports empty"               valid_port_list ""
expect ok      "ports NetBird set"         valid_port_list "80/tcp 443/tcp 3478/udp"
expect refused "port without protocol"     valid_port_list "443"
expect refused "port out of range"         valid_port_list "70000/tcp"
expect refused "port bad protocol"         valid_port_list "53/icmp"

tmp="$(mktemp -d)"
ssh-keygen -q -t ed25519 -N "" -C test -f "$tmp/k" > /dev/null
cp "$tmp/k.pub" "$tmp/good"
printf '# comment only\n' > "$tmp/comment"
printf 'ssh-ed25519 not-a-key test\n' > "$tmp/bad"
expect ok      "authorized_keys with a real key" has_valid_public_key "$tmp/good"
expect refused "authorized_keys with a comment"  has_valid_public_key "$tmp/comment"
expect refused "authorized_keys with junk"       has_valid_public_key "$tmp/bad"
expect refused "authorized_keys missing"         has_valid_public_key "$tmp/missing"
rm -rf "$tmp"

if [[ "$failures" -eq 0 ]]; then echo "All lib checks passed."; else echo "$failures check(s) failed."; exit 1; fi
