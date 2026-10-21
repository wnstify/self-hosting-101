#!/usr/bin/env bash
# Check a running self-hosted NetBird server. Runs on the server. Changes nothing.
#
#   NETBIRD_DOMAIN=netbird.your-domain.com ./verify.sh
#
# Expected result: no FAIL lines and "All NetBird checks passed."
# Right after the install, the certificate can take a minute; rerun if only the
# HTTPS checks fail.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

domain="${NETBIRD_DOMAIN:-}"
[[ -n "$domain" ]] || { echo "Set NETBIRD_DOMAIN." >&2; exit 2; }

fails=0
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; fails=$((fails + 1)); }

# Containers.
running="$(docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null)"
for c in netbird-server netbird-dashboard netbird-traefik; do
  line="$(echo "$running" | awk -v c="$c" '$1 == c')"
  if [[ -n "$line" ]]; then pass "container $line"; else fail "container $c is not running"; fi
done

# Listening ports on this host.
ss -Hltn 2>/dev/null | awk '{print $4}' | grep -Eq '[:.]443$' && pass "listening on 443/tcp" || fail "nothing listens on 443/tcp"
ss -Hltn 2>/dev/null | awk '{print $4}' | grep -Eq '[:.]80$' && pass "listening on 80/tcp" || fail "nothing listens on 80/tcp"
ss -Hlun 2>/dev/null | awk '{print $4}' | grep -Eq '[:.]3478$' && pass "listening on 3478/udp" || fail "nothing listens on 3478/udp"

# HTTPS with a certificate a normal client trusts (no -k anywhere).
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "https://$domain/" 2>/dev/null)"
if [[ "$code" == "200" ]]; then pass "https://$domain/ returns 200 with a trusted certificate"; else fail "https://$domain/ returned '${code:-no answer}' (certificate or routing problem)"; fi

code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "https://$domain/oauth2/.well-known/openid-configuration" 2>/dev/null)"
if [[ "$code" == "200" ]]; then pass "login service answers"; else fail "login service returned '${code:-no answer}'"; fi

if command -v openssl > /dev/null 2>&1; then
  issuer="$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)"
  if [[ "$issuer" == *"Let's Encrypt"* ]]; then pass "certificate from Let's Encrypt"; else fail "certificate issuer: ${issuer:-unknown}"; fi
else
  echo "NOTE openssl is not installed; skipped the certificate issuer check (the HTTPS checks above still prove it is trusted)"
fi

loc="$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 15 "http://$domain/" 2>/dev/null)"
if [[ "$loc" =~ ^30[1278]\ https:// ]]; then pass "port 80 redirects to HTTPS"; else fail "port 80 answered '$loc', expected a redirect to https"; fi

if [[ "$fails" -eq 0 ]]; then
  echo "All NetBird checks passed."
else
  echo "$fails check(s) failed."
  exit 1
fi
