#!/usr/bin/env bash
# Check a running self-hosted Pangolin server. Runs on the server. Changes nothing.
#
#   PANGOLIN_DOMAIN=pangolin.your-domain.com ./verify.sh
#
# Checks CrowdSec too when docker-compose.yml has it. Expected result: no FAIL
# lines and "All Pangolin checks passed." Right after the install, the
# certificate can take a minute; rerun if only the HTTPS checks fail.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

domain="${PANGOLIN_DOMAIN:-}"
[[ -n "$domain" ]] || { echo "Set PANGOLIN_DOMAIN." >&2; exit 2; }

fails=0
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; fails=$((fails + 1)); }

crowdsec=0
grep -Eq '^[[:space:]]+crowdsec:[[:space:]]*$' "$PANGOLIN_DIR/docker-compose.yml" 2>/dev/null && crowdsec=1

# Containers.
containers="pangolin gerbil traefik"
[[ $crowdsec -eq 1 ]] && containers="$containers crowdsec"
for c in $containers; do
  state="$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$c" 2>/dev/null)"
  image="$(docker inspect -f '{{.Config.Image}}' "$c" 2>/dev/null)"
  case "$state" in
    "running "|"running healthy") pass "container $c $image ($state)" ;;
    *) fail "container $c is '${state:-missing}'" ;;
  esac
done

# Listening ports on this host.
ss -Hltn 2>/dev/null | awk '{print $4}' | grep -Eq '[:.]443$' && pass "listening on 443/tcp" || fail "nothing listens on 443/tcp"
ss -Hltn 2>/dev/null | awk '{print $4}' | grep -Eq '[:.]80$' && pass "listening on 80/tcp" || fail "nothing listens on 80/tcp"
ss -Hlun 2>/dev/null | awk '{print $4}' | grep -Eq '[:.]51820$' && pass "listening on 51820/udp (sites)" || fail "nothing listens on 51820/udp"
ss -Hlun 2>/dev/null | awk '{print $4}' | grep -Eq '[:.]21820$' && pass "listening on 21820/udp (clients)" || fail "nothing listens on 21820/udp"

# HTTPS with a certificate a normal client trusts (no -k anywhere).
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "https://$domain/" 2>/dev/null)"
if [[ "$code" =~ ^(200|30[1278])$ ]]; then pass "https://$domain/ answers $code with a trusted certificate"; else fail "https://$domain/ returned '${code:-no answer}' (certificate, routing or CrowdSec problem)"; fi

if command -v openssl > /dev/null 2>&1; then
  issuer="$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)"
  if [[ "$issuer" == *"Let's Encrypt"* ]]; then pass "certificate from Let's Encrypt"; else fail "certificate issuer: ${issuer:-unknown}"; fi
else
  echo "NOTE openssl is not installed; skipped the certificate issuer check (the HTTPS check above still proves it is trusted)"
fi

loc="$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 15 "http://$domain/" 2>/dev/null)"
if [[ "$loc" =~ ^30[1278]\ https:// ]]; then pass "port 80 redirects to HTTPS"; else fail "port 80 answered '$loc', expected a redirect to https"; fi

# CrowdSec: bouncer registered and the three changed defaults still in place.
if [[ $crowdsec -eq 1 ]]; then
  if docker exec crowdsec cscli bouncers list -o raw 2>/dev/null | grep -q '^traefik-bouncer,'; then
    pass "traefik-bouncer is registered with CrowdSec"
  else
    fail "traefik-bouncer is not registered (docker exec crowdsec cscli bouncers list)"
  fi
  dyn="$PANGOLIN_DIR/config/traefik/dynamic_config.yml"
  sta="$PANGOLIN_DIR/config/traefik/traefik_config.yml"
  pro="$PANGOLIN_DIR/config/crowdsec/profiles.yaml"
  unreadable=""
  for f in "$dyn" "$sta" "$pro"; do [[ -r "$f" ]] || unreadable="$unreadable $f"; done
  if [[ -n "$unreadable" ]]; then
    fail "cannot read:$unreadable; run verify.sh as the admin user that owns $PANGOLIN_DIR"
  else
    if grep -q 'PUT_YOUR_BOUNCER_KEY' "$dyn"; then fail "the bouncer key in dynamic_config.yml is still the placeholder"; else pass "bouncer key is set"; fi
    if grep -Eq 'type:[[:space:]]*captcha' "$pro"; then fail "profiles.yaml still uses captcha"; else pass "profiles.yaml bans, no captcha"; fi
    if grep -q 'minDuration' "$sta"; then fail "traefik_config.yml still filters the access log with minDuration"; else pass "access log keeps fast requests"; fi
    if grep -q 'forwardedHeadersTrustedIPs' "$dyn"; then fail "dynamic_config.yml still trusts forwarded headers"; else pass "forwarded headers trusted from nobody"; fi
  fi
else
  echo "NOTE CrowdSec is not installed; skipped its checks"
fi

if [[ "$fails" -eq 0 ]]; then
  echo "All Pangolin checks passed."
else
  echo "$fails check(s) failed."
  exit 1
fi
