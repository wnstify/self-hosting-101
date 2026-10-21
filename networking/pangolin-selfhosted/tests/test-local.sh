#!/usr/bin/env bash
# Local checks for the self-hosted Pangolin scripts. Touch no server and make no
# network request. Run from the repository root:
#   bash networking/pangolin-selfhosted/tests/test-local.sh
set -u
topic="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib.sh
. "$topic/lib.sh"

failures=0
ok() { echo "PASS $*"; }
bad() { echo "FAIL $*"; failures=$((failures + 1)); }
expect() {
  local want="$1" desc="$2"; shift 2
  if "$@"; then got=ok; else got=refused; fi
  if [[ "$got" == "$want" ]]; then ok "$desc"; else bad "$desc (wanted $want, got $got)"; fi
}

expect ok      "fqdn pangolin.your-domain.com"   valid_fqdn pangolin.your-domain.com
expect refused "fqdn without a dot"              valid_fqdn pangolin
expect refused "fqdn with scheme"                valid_fqdn https://pangolin.example.org
expect refused "fqdn with trailing dot"          valid_fqdn pangolin.your-domain.com.
expect ok      "reserved pangolin.example.com"   reserved_domain pangolin.example.com
expect refused "not reserved your-domain.com"   reserved_domain your-domain.com
expect ok      "email on a real domain"          valid_email you@your-domain.com
expect refused "email at example.com"            valid_email example@example.com
expect refused "empty email"                     valid_email ""

expect ok "pinned checksum is 64 hex characters" bash -c "[[ '$PANGOLIN_INSTALLER_SHA256_DEFAULT' =~ ^[0-9a-f]{64}\$ ]]"

# install-pangolin.sh must refuse before any download or preflight.
refuses() {
  local desc="$1" script="$2" pattern="$3"; shift 3
  local out rc
  out="$(env "$@" bash "$topic/$script" 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 && "$out" == *"$pattern"* ]]; then ok "$desc"; else bad "$desc (rc=$rc: $out)"; fi
}
refuses "installer refuses an unpinned version"  install-pangolin.sh "not the tested release" PANGOLIN_VERSION=1.99.0 PANGOLIN_DOMAIN=pangolin.your-domain.com PANGOLIN_LETSENCRYPT_EMAIL=you@your-domain.com
refuses "installer refuses example.com domain"   install-pangolin.sh "your own name"          PANGOLIN_DOMAIN=pangolin.example.com PANGOLIN_LETSENCRYPT_EMAIL=you@your-domain.com
refuses "installer refuses a missing domain"     install-pangolin.sh "your own name"          PANGOLIN_LETSENCRYPT_EMAIL=you@your-domain.com
refuses "installer refuses example.com email"    install-pangolin.sh "real domain"            PANGOLIN_DOMAIN=pangolin.your-domain.com PANGOLIN_LETSENCRYPT_EMAIL=example@example.com
refuses "crowdsec refuses an unpinned version"   install-crowdsec.sh "not the tested release" PANGOLIN_VERSION=1.99.0
if [[ ! -e /opt/pangolin/config/config.yml ]]; then
  refuses "crowdsec refuses without an installation" install-crowdsec.sh "install-pangolin.sh first"
fi
out="$(bash "$topic/ban-test.sh" 2>&1)"; rc=$?
if [[ $rc -eq 2 && "$out" == *usage* ]]; then ok "ban-test.sh needs a target and a domain"; else bad "ban-test.sh without arguments (rc=$rc)"; fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# run_answered against a fake installer that asks like the real one in plain
# prompt mode: a question without a newline, then one line from stdin.
cat > "$work/fake-installer" <<'FAKE'
#!/usr/bin/env bash
ask() { printf '%s ' "$1"; IFS= read -r a || a="<eof>"; echo "$1=$a" >> "$ANSWERS"; }
ask "Enter the installation directory (default: /opt/pangolin)"
[[ "${SKIP_CREATE:-0}" == "1" ]] || ask "Directory /opt/pangolin does not exist. Create it? [Y/n]"
ask "Do you want to install the Enterprise version of Pangolin? [y/N]"
[[ "${SURPRISE:-0}" == "1" ]] && ask "A question nobody expected?"
ask "Enter your base domain (no subdomain e.g. example.com)"
echo "done"
FAKE
chmod +x "$work/fake-installer"
steps=("Enter the installation directory|" "?does not exist\. Create it\?|y" "install the Enterprise version|n" "Enter your base domain|pangolin.your-domain.com")

export ANSWERS="$work/answers"
: > "$ANSWERS"
PANGOLIN_SUDO="" STEP_TIMEOUT=5 run_answered "$work/log" "$work" "${steps[@]}" -- "$work/fake-installer" > /dev/null; rc=$?
want=$'Enter the installation directory (default: /opt/pangolin)=\nDirectory /opt/pangolin does not exist. Create it? [Y/n]=y\nDo you want to install the Enterprise version of Pangolin? [y/N]=n\nEnter your base domain (no subdomain e.g. example.com)=pangolin.your-domain.com'
if [[ $rc -eq 0 && "$(cat "$ANSWERS")" == "$want" ]]; then ok "answers go to the right questions, one at a time"; else bad "answer order (rc=$rc): $(cat "$ANSWERS")"; fi

: > "$ANSWERS"
SKIP_CREATE=1 PANGOLIN_SUDO="" STEP_TIMEOUT=5 run_answered "$work/log" "$work" "${steps[@]}" -- "$work/fake-installer" > /dev/null; rc=$?
if [[ $rc -eq 0 && "$(grep -c . "$ANSWERS")" -eq 3 && "$(sed -n 2p "$ANSWERS")" == *"Enterprise"*"=n" ]]; then ok "an optional question that is not asked is skipped"; else bad "optional skip (rc=$rc): $(cat "$ANSWERS")"; fi

: > "$ANSWERS"
SURPRISE=1 PANGOLIN_SUDO="" STEP_TIMEOUT=2 run_answered "$work/log" "$work" "${steps[@]}" -- "$work/fake-installer" > /dev/null; rc=$?
if [[ $rc -eq 3 ]] && ! grep -q "base domain" "$ANSWERS"; then ok "an unexpected question stops the run"; else bad "unexpected question (rc=$rc): $(cat "$ANSWERS")"; fi

printf 'SETUP TOKEN GENERATED\nabc123secret\n\n\nlast line\n' > "$work/tok.log"
if ! log_tail "$work/tok.log" | grep -q abc123secret; then ok "log_tail hides the setup token"; else bad "log_tail printed the setup token"; fi

# The three CrowdSec edits, on synthetic files shaped like the 1.24.0 ones.
cat > "$work/profiles.yaml" <<'EOF'
name: captcha_remediation
decisions:
  - type: captcha
    duration: 4h
---
name: default_ip_remediation
decisions:
 - type: ban
   duration: 4h
EOF
cat > "$work/traefik_config.yml" <<'EOF'
accessLog:
  filePath: "/var/log/traefik/access.log"
  filters:
    statusCodes:
      - "200-299"
    retryAttempts: true
    minDuration: "100ms"  # comment
  bufferingSize: 100
EOF
cat > "$work/dynamic_config.yml" <<'EOF'
        crowdsec:
          crowdsecLapiKey: "0123456789abcdef"
          forwardedHeadersTrustedIPs: # Forwarded headers trusted IPs
            - "0.0.0.0/0" # All IP addresses are trusted for forwarded headers
          clientTrustedIPs:
            - "10.0.0.0/8"
EOF
sed 's|"0.0.0.0/0"|"203.0.113.10/32"|' "$work/dynamic_config.yml" > "$work/dynamic_custom.yml"
sed 's|0123456789abcdef|PUT_YOUR_BOUNCER_KEY_HERE_OR_IT_WILL_NOT_WORK|' "$work/dynamic_config.yml" > "$work/dynamic_placeholder.yml"

# die() exits, so run each edit in a subshell and read its status and CHANGED.
edit() {
  local out rc
  out="$(PANGOLIN_SUDO=""; CHANGED=0; "$@" > /dev/null 2>&1; echo "$CHANGED")"; rc=$?
  echo "rc=$rc changed=${out:-0}"
}

r="$(edit profiles_use_ban "$work/profiles.yaml")"
if [[ "$r" == "rc=0 changed=1" && "$(grep -c 'type: ban' "$work/profiles.yaml")" -eq 2 ]] && ! grep -q 'type: captcha' "$work/profiles.yaml"; then ok "captcha becomes ban"; else bad "captcha to ban ($r)"; fi
r="$(edit profiles_use_ban "$work/profiles.yaml")"
if [[ "$r" == "rc=0 changed=0" ]]; then ok "captcha change is idempotent"; else bad "captcha change twice ($r)"; fi

r="$(edit access_log_keeps_fast_requests "$work/traefik_config.yml")"
if [[ "$r" == "rc=0 changed=1" ]] && ! grep -q minDuration "$work/traefik_config.yml" && grep -q 'retryAttempts: true' "$work/traefik_config.yml" && grep -q 'bufferingSize' "$work/traefik_config.yml"; then ok "minDuration line removed, neighbours kept"; else bad "minDuration ($r)"; fi

r="$(edit forwarded_headers_trusted_from_nobody "$work/dynamic_config.yml")"
if [[ "$r" == "rc=0 changed=1" ]] && ! grep -q forwardedHeadersTrustedIPs "$work/dynamic_config.yml" && ! grep -q '0.0.0.0/0' "$work/dynamic_config.yml" && grep -q 'clientTrustedIPs' "$work/dynamic_config.yml" && grep -q '10.0.0.0/8' "$work/dynamic_config.yml"; then ok "trusted forwarded headers removed, client allowlist kept"; else bad "forwardedHeadersTrustedIPs ($r)"; fi

r="$(edit forwarded_headers_trusted_from_nobody "$work/dynamic_custom.yml")"
if [[ "$r" == rc=1* ]] && grep -q 203.0.113.10 "$work/dynamic_custom.yml"; then ok "an owner's own trusted proxy list is left alone and refused"; else bad "custom trusted list ($r)"; fi

r="$(edit forwarded_headers_trusted_from_nobody "$work/dynamic_placeholder.yml")"
if [[ "$r" == rc=1* ]]; then ok "a placeholder bouncer key is refused"; else bad "placeholder bouncer key ($r)"; fi

printf 'log:\n  level: INFO\n' > "$work/no_access_log.yml"
r="$(edit access_log_keeps_fast_requests "$work/no_access_log.yml")"
if [[ "$r" == rc=1* ]]; then ok "a missing access log is refused"; else bad "missing access log ($r)"; fi

if [[ "$failures" -eq 0 ]]; then echo "All local checks passed."; else echo "$failures check(s) failed."; exit 1; fi
