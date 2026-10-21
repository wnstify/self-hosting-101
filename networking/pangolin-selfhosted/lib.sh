#!/usr/bin/env bash
# Shared checks for the self-hosted Pangolin scripts. Sourced, not run.

# Tested release. Change these together, and only after a live test. The
# answer sequences in install-pangolin.sh and install-crowdsec.sh follow this
# release's questions.
PANGOLIN_VERSION_DEFAULT="1.24.0"
PANGOLIN_INSTALLER_SHA256_DEFAULT="345cdc632230674fedcf55a431d561dae268cdb7ec2cd210e3ca1836fe95d76e"

PANGOLIN_DIR="/opt/pangolin"
INSTALLER_DIR="${INSTALLER_DIR:-$HOME/pangolin-installer}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

# Labels of letters, digits and hyphens, at least one dot, no scheme, port or
# trailing dot.
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

# Download the pinned installer into INSTALLER_DIR, or reuse a copy already
# there, and refuse it unless its SHA-256 matches. Prints the installer path.
fetch_installer() {
  local version="$1" expected="$2" path="$INSTALLER_DIR/installer" url actual
  mkdir -p "$INSTALLER_DIR"
  if [[ ! -f "$path" ]]; then
    url="https://github.com/fosrl/pangolin/releases/download/${version}/installer_linux_amd64"
    info "Downloading $url" >&2
    curl -fsSL "$url" -o "$path.part" || die "Download failed: $url"
    mv "$path.part" "$path"
  fi
  actual="$(sha256_of "$path")"
  if [[ "$actual" != "$expected" ]]; then
    rm -f "$path"
    die "Checksum mismatch for the Pangolin installer (expected $expected, got $actual). Nothing was run."
  fi
  chmod 755 "$path"
  info "Installer checksum matches the tested release ($version)" >&2
  echo "$path"
}

# Run the installer with sudo and answer its questions one at a time.
#
#   run_answered LOG DIR "pattern|answer" ... -- installer args
#
# The installer drops to plain line prompts when stdin is not a terminal, and
# each prompt reads stdin afresh. So every answer is written only after its
# question has appeared in the output; writing ahead would let one prompt
# swallow the next answer. A pattern is an extended regex matched against the
# output since the previous answer. A step whose pattern starts with "?" is
# optional: it is skipped when the next step's question appears first. Any
# question that does not come within STEP_TIMEOUT seconds stops the run.
run_answered() {
  local log="$1" dir="$2"; shift 2
  local steps=() args=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do steps+=("$1"); shift; done
  [[ "${1:-}" == "--" ]] && shift
  args=("$@")

  local fifo pid offset=0 i=0 timeout="${STEP_TIMEOUT:-300}"
  fifo="$(mktemp -u "${TMPDIR:-/tmp}/pangolin-answers.XXXXXX")"
  mkfifo -m 600 "$fifo"
  : > "$log"
  chmod 600 "$log"
  # PANGOLIN_SUDO is for the local tests, which run a fake installer.
  local sudo_cmd="${PANGOLIN_SUDO-sudo -n}"
  # shellcheck disable=SC2086
  (cd "$dir" && exec $sudo_cmd "${args[@]}" < "$fifo" > "$log" 2>&1) &
  pid=$!
  exec 3> "$fifo"
  rm -f "$fifo"

  local new step pat ans optional next_pat start
  while [[ $i -lt ${#steps[@]} ]]; do
    step="${steps[$i]}"
    pat="${step%%|*}"
    ans="${step#*|}"
    optional=0
    if [[ "$pat" == \?* ]]; then optional=1; pat="${pat#\?}"; fi
    next_pat=""
    if [[ $optional -eq 1 && $((i + 1)) -lt ${#steps[@]} ]]; then
      next_pat="${steps[$((i + 1))]%%|*}"
      next_pat="${next_pat#\?}"
    fi
    start=$SECONDS
    while :; do
      new="$(tail -c +"$((offset + 1))" "$log" 2>/dev/null)"
      if grep -Eq -- "$pat" <<< "$new"; then
        offset="$(wc -c < "$log" | tr -d ' ')"
        printf '%s\n' "$ans" >&3
        info "Answered: $pat -> ${ans:-(default)}"
        break
      fi
      if [[ -n "$next_pat" ]] && grep -Eq -- "$next_pat" <<< "$new"; then
        info "Skipped (not asked): $pat"
        break
      fi
      if ! kill -0 "$pid" 2>/dev/null; then
        exec 3>&-
        wait "$pid"
        return 2
      fi
      if (( SECONDS - start > timeout )); then
        # Stop the installer before closing its input: with stdin closed it
        # would carry on and take the defaults for every question left.
        # shellcheck disable=SC2086
        $sudo_cmd pkill -f "${args[0]}" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null
        exec 3>&-
        return 3
      fi
      sleep 0.3
    done
    i=$((i + 1))
  done
  exec 3>&-
  wait "$pid"
}

# The last lines of the installer log, without the setup token.
log_tail() {
  sed -E '/SETUP TOKEN/,+3d' "$1" | tail -n "${2:-25}"
}

# The three CrowdSec defaults install-crowdsec.sh changes. Each refuses when
# the file is not what the tested release writes, and sets CHANGED=1 when it
# edits. Files are root-owned, so edits go through sudo; reads do not.
rewrite_file() {
  local f="$1" tmp; shift
  tmp="$(mktemp)"
  "$@" < "$f" > "$tmp" || { rm -f "$tmp"; die "Could not rewrite $f."; }
  # shellcheck disable=SC2086
  ${PANGOLIN_SUDO-sudo} tee "$f" < "$tmp" > /dev/null || { rm -f "$tmp"; die "Could not write $f."; }
  rm -f "$tmp"
}

profiles_use_ban() {
  local f="$1"
  if grep -Eq '^[[:space:]]*-?[[:space:]]*type:[[:space:]]*captcha[[:space:]]*$' "$f"; then
    rewrite_file "$f" sed -E 's/^([[:space:]]*-?[[:space:]]*type:[[:space:]]*)captcha[[:space:]]*$/\1ban/'
    CHANGED=1
  fi
  grep -Eq 'type:[[:space:]]*captcha' "$f" && die "$f still mentions a captcha remedy; check it by hand."
  grep -Eq 'type:[[:space:]]*ban' "$f" || die "$f has no ban remedy; check it by hand."
  return 0
}

access_log_keeps_fast_requests() {
  local f="$1"
  grep -Eq '^accessLog:' "$f" || die "$f has no accessLog section; CrowdSec would read nothing."
  if grep -Eq '^[[:space:]]*minDuration:' "$f"; then
    rewrite_file "$f" grep -Ev '^[[:space:]]*minDuration:'
    CHANGED=1
  fi
  grep -q 'minDuration' "$f" && die "$f still has minDuration; check it by hand."
  return 0
}

forwarded_headers_trusted_from_nobody() {
  local f="$1" next
  if grep -q 'forwardedHeadersTrustedIPs:' "$f"; then
    # Delete the key only together with the single list entry the installer
    # writes. Anything else under it is the owner's and needs a look by hand.
    next="$(grep -A1 'forwardedHeadersTrustedIPs:' "$f" | sed -n 2p)"
    [[ "$next" =~ ^[[:space:]]*-[[:space:]]*\"?0\.0\.0\.0/0\"?([[:space:]]*#.*)?$ ]] \
      || die "forwardedHeadersTrustedIPs in $f is followed by '$next', not the default 0.0.0.0/0; check it by hand."
    rewrite_file "$f" awk 'skip > 0 {skip--; next} /forwardedHeadersTrustedIPs:/ {skip = 1; next} {print}'
    CHANGED=1
  fi
  grep -q 'forwardedHeadersTrustedIPs' "$f" && die "$f still trusts forwarded headers; check it by hand."
  grep -q 'PUT_YOUR_BOUNCER_KEY' "$f" && die "The bouncer key was never filled in $f; see the guide's recovery section."
  return 0
}
