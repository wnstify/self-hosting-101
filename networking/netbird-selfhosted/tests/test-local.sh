#!/usr/bin/env bash
# Local checks for the self-hosted NetBird scripts. Touch no server and make no
# network request. Run from the repository root:
#   bash networking/netbird-selfhosted/tests/test-local.sh
set -u
topic="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib.sh
. "$topic/lib.sh"

failures=0
expect() {
  local want="$1" desc="$2"; shift 2
  if "$@"; then got=ok; else got=refused; fi
  if [[ "$got" == "$want" ]]; then echo "PASS $desc"; else echo "FAIL $desc (wanted $want, got $got)"; failures=$((failures + 1)); fi
}

expect ok      "fqdn netbird.your-domain.com"    valid_fqdn netbird.your-domain.com
expect refused "fqdn without a dot"               valid_fqdn netbird
expect refused "fqdn with scheme"                 valid_fqdn https://netbird.example.org
expect refused "fqdn with trailing dot"           valid_fqdn netbird.your-domain.com.
expect refused "fqdn with port"                   valid_fqdn netbird.your-domain.com:443

expect ok      "reserved netbird.example.com"     reserved_domain netbird.example.com
expect ok      "reserved EXAMPLE.ORG"             reserved_domain EXAMPLE.ORG
expect ok      "reserved home.test"               reserved_domain home.test
expect ok      "reserved box.local"               reserved_domain box.local
expect refused "not reserved your-domain.com"    reserved_domain your-domain.com
expect refused "not reserved myexample.com"       reserved_domain myexample.com

expect ok      "email on a real domain"           valid_email you@your-domain.com
expect refused "email at example.com"             valid_email example@example.com
expect refused "email at a .test domain"          valid_email me@lab.test
expect refused "email without @"                  valid_email you.your-domain.com
expect refused "email with two @"                 valid_email a@b@your-domain.com
expect refused "empty email"                      valid_email ""

# The pinned checksum must have the shape of a SHA-256 digest.
expect ok "pinned checksum is 64 hex characters" bash -c "[[ '$NETBIRD_INSTALLER_SHA256_DEFAULT' =~ ^[0-9a-f]{64}\$ ]]"

# install-netbird.sh must refuse before any download or preflight.
refuses() {
  local desc="$1" pattern="$2"; shift 2
  local out rc
  out="$(env "$@" bash "$topic/install-netbird.sh" 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"$pattern"* ]]; then echo "PASS $desc"; else echo "FAIL $desc (rc=$rc: $out)"; failures=$((failures + 1)); fi
}
refuses "installer refuses example.com email"       "real domain"            NETBIRD_DOMAIN=netbird.your-domain.com NETBIRD_LETSENCRYPT_EMAIL=example@example.com
refuses "installer refuses a missing email"         "real domain"            NETBIRD_DOMAIN=netbird.your-domain.com
refuses "installer refuses an unpinned version"     "not the tested release" NETBIRD_VERSION=v0.99.0 NETBIRD_DOMAIN=netbird.your-domain.com NETBIRD_LETSENCRYPT_EMAIL=you@your-domain.com

if [[ "$failures" -eq 0 ]]; then echo "All local checks passed."; else echo "$failures check(s) failed."; exit 1; fi
