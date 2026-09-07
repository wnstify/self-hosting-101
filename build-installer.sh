#!/bin/bash
set -euo pipefail
umask 077

WORK_DIR="${WORK_DIR:-/tmp/proxmox-auto}"
CHROOT_DIR="${CHROOT_DIR:-/opt/proxmox-auto-trixie}"
ISO_NAME=proxmox-ve_9.2-1.iso
ISO_SHA256=4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c
KEY_FINGERPRINT=24B30F06ECC1836A4E5EFECBA7BCD1420BFE778E

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ ${EUID} -eq 0 ]] || fail 'Run as root'
[[ "$WORK_DIR" == /* && "$CHROOT_DIR" == /* ]] || fail 'Use absolute directories'
for item in "$ISO_NAME" answer.toml first-boot-disable-ipv6.sh; do
    [[ -f "$WORK_DIR/$item" ]] || fail "Missing $WORK_DIR/$item"
done
chmod 0700 "$WORK_DIR"
chmod 0600 "$WORK_DIR/answer.toml"
! grep -q 'REPLACE_WITH_' "$WORK_DIR/answer.toml" || fail 'Replace answer placeholders first'
echo "$ISO_SHA256  $WORK_DIR/$ISO_NAME" | sha256sum -c -

mounted=0
cleanup() { if [[ $mounted == 1 ]]; then umount "$CHROOT_DIR/tmp/work"; fi; }
trap cleanup EXIT
apt-get -o APT::Update::Error-Mode=any update
DEBIAN_FRONTEND=noninteractive apt-get install -y debootstrap ca-certificates curl gnupg qemu-system-x86
if [[ ! -x "$CHROOT_DIR/bin/bash" ]]; then
    debootstrap trixie "$CHROOT_DIR" https://deb.debian.org/debian
fi
mkdir -p "$CHROOT_DIR/tmp/work"
! mountpoint -q "$CHROOT_DIR/tmp/work" || fail 'Chroot work directory is already mounted'
mount --bind "$WORK_DIR" "$CHROOT_DIR/tmp/work"
mounted=1
# Do not use shell tracing: validation errors can contain credential fields.
chroot "$CHROOT_DIR" /bin/bash -eu -o pipefail -s -- "$KEY_FINGERPRINT" "$ISO_NAME" <<'CHROOT'
umask 077
apt-get -o APT::Update::Error-Mode=any update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
curl -fLsS --retry 4 https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg \
    -o /usr/share/keyrings/proxmox-release-trixie.gpg
fingerprint=$(gpg --show-keys --with-colons /usr/share/keyrings/proxmox-release-trixie.gpg | awk -F: '$1=="fpr" {print $10; exit}')
[[ "$fingerprint" == "$1" ]] || { echo 'Release key fingerprint mismatch' >&2; exit 1; }
chmod 0644 /usr/share/keyrings/proxmox-release-trixie.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/proxmox-release-trixie.gpg] http://download.proxmox.com/debian/pve trixie pve-no-subscription' > /etc/apt/sources.list.d/pve.list
apt-get -o APT::Update::Error-Mode=any update
DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-auto-install-assistant
if ! proxmox-auto-install-assistant validate-answer /tmp/work/answer.toml > /tmp/work/answer-validation.log 2>&1; then
    echo 'Answer validation failed. Review the private answer-validation.log; do not publish it.' >&2
    exit 1
fi
echo 'Answer validation passed'
proxmox-auto-install-assistant prepare-iso \
    --fetch-from iso \
    --answer-file /tmp/work/answer.toml \
    --on-first-boot /tmp/work/first-boot-disable-ipv6.sh \
    --output /tmp/work/proxmox-auto.iso \
    "/tmp/work/$2"
chmod 0600 /tmp/work/proxmox-auto.iso
CHROOT
cleanup
mounted=0
trap - EXIT
sha256sum "$WORK_DIR/proxmox-auto.iso"
