#!/usr/bin/env bash
# Harden a fresh Debian 13 VPS in three phases. Runs on the server.
#
#   sudo ADMIN_USER=alice ./harden.sh user       # update, admin user, sudo, key copy
#   sudo ADMIN_USER=alice CONFIRMED_LOGIN=alice ./harden.sh lock
#                                                 # keys only, no root login
#   sudo ALLOW_PORTS="80/tcp 443/tcp" ./harden.sh firewall
#
# Optional settings:
#   SUDO_MODE=nopasswd|password   default nopasswd (see the guide for the trade-off)
#   SSH_ALLOW_FROM=any|IPv4[/CIDR] default any; who may reach port 22 through ufw
#   ALLOW_PORTS="PORT/proto ..."   extra inbound ports for ufw
#
# The lock phase refuses to run until the owner has logged in as ADMIN_USER in a
# second session and confirmed it by setting CONFIRMED_LOGIN to the same name.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$here/lib.sh"

DROPIN=/etc/ssh/sshd_config.d/00-hardening.conf

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "Run as root (directly or with sudo)."
}

require_debian13() {
  [[ -r /etc/os-release ]] || die "/etc/os-release is missing."
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "13" ]] \
    || die "This guide is tested on Debian 13 only (found ${ID:-unknown} ${VERSION_ID:-unknown})."
}

require_admin_user_var() {
  valid_admin_user "${ADMIN_USER:-}" \
    || die "Set ADMIN_USER to a lowercase user name other than root (got '${ADMIN_USER:-}')."
}

phase_user() {
  require_admin_user_var
  local mode="${SUDO_MODE:-nopasswd}"
  [[ "$mode" == "nopasswd" || "$mode" == "password" ]] || die "SUDO_MODE must be nopasswd or password."
  has_valid_public_key /root/.ssh/authorized_keys \
    || die "/root/.ssh/authorized_keys has no valid public key. Add your key at server creation first."

  info "Updating packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  apt-get upgrade -y -q -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold

  if id "$ADMIN_USER" > /dev/null 2>&1; then
    info "User $ADMIN_USER already exists; keeping it"
  else
    info "Creating user $ADMIN_USER"
    adduser --disabled-password --comment "" "$ADMIN_USER"
  fi
  usermod -aG sudo "$ADMIN_USER"

  local sudoers="/etc/sudoers.d/$ADMIN_USER" tmp
  tmp="$(mktemp)"
  if [[ "$mode" == "nopasswd" ]]; then
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$ADMIN_USER" > "$tmp"
  else
    printf '%s ALL=(ALL) ALL\n' "$ADMIN_USER" > "$tmp"
  fi
  visudo -cf "$tmp" > /dev/null || { rm -f "$tmp"; die "The new sudoers file failed visudo; nothing was installed."; }
  install -m 440 -o root -g root "$tmp" "$sudoers"
  rm -f "$tmp"
  visudo -c > /dev/null || die "visudo -c failed after installing $sudoers. Fix it before closing this session."

  info "Copying root's authorized keys to $ADMIN_USER"
  install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
  install -m 600 -o "$ADMIN_USER" -g "$ADMIN_USER" /root/.ssh/authorized_keys "/home/$ADMIN_USER/.ssh/authorized_keys"
  has_valid_public_key "/home/$ADMIN_USER/.ssh/authorized_keys" || die "The key copy for $ADMIN_USER is not readable."

  if [[ "$mode" == "password" ]]; then
    echo
    echo "SUDO_MODE=password: $ADMIN_USER has no password yet. Set one in this root session:"
    echo "  passwd $ADMIN_USER"
  fi
  echo
  echo "Next: keep this root session open. In a second terminal, log in as"
  echo "$ADMIN_USER and run 'sudo whoami' (expect: root). Then run the lock phase."
}

phase_lock() {
  require_admin_user_var
  [[ "${CONFIRMED_LOGIN:-}" == "$ADMIN_USER" ]] \
    || die "Log in as $ADMIN_USER in a second session first, then rerun with CONFIRMED_LOGIN=$ADMIN_USER."
  id -nG "$ADMIN_USER" | tr ' ' '\n' | grep -qx sudo || die "$ADMIN_USER is not in the sudo group. Run the user phase."
  has_valid_public_key "/home/$ADMIN_USER/.ssh/authorized_keys" || die "$ADMIN_USER has no valid authorized key."

  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<'EOF'
# Self-Hosting 101: keys only. The 00- prefix makes this file load first,
# and sshd keeps the first value it reads for each setting.
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
  install -m 644 -o root -g root "$tmp" "$DROPIN"
  rm -f "$tmp"
  if ! sshd -t; then
    rm -f "$DROPIN"
    die "sshd -t rejected the configuration; the drop-in was removed and nothing was reloaded."
  fi
  systemctl reload ssh

  local effective
  effective="$(sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication) ')"
  echo "$effective"
  echo "$effective" | grep -qi '^permitrootlogin no$' || die "permitrootlogin is not 'no'. Check other files in /etc/ssh/sshd_config.d/."
  echo "$effective" | grep -qi '^passwordauthentication no$' || die "passwordauthentication is not 'no'."
  echo "$effective" | grep -qi '^kbdinteractiveauthentication no$' || die "kbdinteractiveauthentication is not 'no'."
  echo
  echo "Locked. Check from your workstation with verify-ssh.sh before closing any session."
}

phase_firewall() {
  local src="${SSH_ALLOW_FROM:-any}" ports="${ALLOW_PORTS:-}"
  valid_ssh_source "$src" || die "SSH_ALLOW_FROM must be 'any' or an IPv4 address or CIDR (got '$src')."
  valid_port_list "$ports" || die "ALLOW_PORTS must look like '80/tcp 443/tcp 3478/udp' (got '$ports')."

  export DEBIAN_FRONTEND=noninteractive
  command -v ufw > /dev/null || { info "Installing ufw"; apt-get install -y -q ufw; }

  info "Allowing SSH first, so enabling ufw cannot lock you out"
  if [[ "$src" == "any" ]]; then
    ufw allow 22/tcp
  else
    ufw allow from "$src" to any port 22 proto tcp
  fi
  local entry
  for entry in $ports; do
    ufw allow "$entry"
  done
  ufw --force enable
  ufw status verbose
  ufw status | grep -Eq '^22/tcp' || die "No SSH rule is active. Do not close your session; add 'ufw allow 22/tcp'."

  info "Automatic security updates"
  if ! dpkg -s unattended-upgrades > /dev/null 2>&1; then
    apt-get install -y -q unattended-upgrades
    printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
  fi
  systemctl is-enabled unattended-upgrades
  cat /etc/apt/apt.conf.d/20auto-upgrades
}

main() {
  require_root
  require_debian13
  case "${1:-}" in
    user) phase_user ;;
    lock) phase_lock ;;
    firewall) phase_firewall ;;
    *) die "Usage: harden.sh user|lock|firewall (see the header of this script)." ;;
  esac
}

main "$@"
