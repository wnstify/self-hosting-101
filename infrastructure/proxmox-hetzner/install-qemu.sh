#!/bin/bash
# Rescue only. ERASES both approved disks and runs the unattended Proxmox installer in QEMU.
set -euo pipefail
umask 077

WORK_DIR="${WORK_DIR:-/tmp/proxmox-auto}"
INSTALL_ISO="${INSTALL_ISO:-${WORK_DIR}/proxmox-auto.iso}"
TARGET_DISK_1="${TARGET_DISK_1:-}"
TARGET_DISK_2="${TARGET_DISK_2:-}"
EXPECTED_SERIAL_1="${EXPECTED_SERIAL_1:-}"
EXPECTED_SERIAL_2="${EXPECTED_SERIAL_2:-}"
NIC_MAC="${NIC_MAC:-}"
ERASE_CONFIRMED="${ERASE_CONFIRMED:-}"
CHECK_ONLY="${CHECK_ONLY:-0}"
FIRMWARE_MODE="${FIRMWARE_MODE:-}"

fail() { echo "ERROR: $*" >&2; exit 1; }
[[ "$FIRMWARE_MODE" == bios ]] || fail 'Legacy BIOS is mandatory: set FIRMWARE_MODE=bios'
[[ ! -d /sys/firmware/efi ]] || fail 'Rescue is booted in UEFI; configure legacy BIOS boot before continuing'
[[ ${EUID} -eq 0 ]] || fail 'Run as root'
# The erase flag names the approved serials so a stale YES cannot approve other disks.
[[ "$ERASE_CONFIRMED" == "${EXPECTED_SERIAL_1}+${EXPECTED_SERIAL_2}" ]] \
    || fail 'Set ERASE_CONFIRMED to the two approved serials as SERIAL_1+SERIAL_2, in install.env order'
[[ -n "$EXPECTED_SERIAL_1" && -n "$EXPECTED_SERIAL_2" ]] || fail 'Both expected serials are required'
[[ -f "$INSTALL_ISO" ]] || fail "Missing installer ISO: $INSTALL_ISO"
[[ -c /dev/kvm ]] || fail '/dev/kvm is unavailable'
[[ "$NIC_MAC" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || fail 'A valid NIC_MAC is required'
for tool in qemu-system-x86_64 lsblk readlink flock; do command -v "$tool" >/dev/null || fail "Missing $tool"; done
[[ -n "$TARGET_DISK_1" && -n "$TARGET_DISK_2" ]] || fail 'Both target disks are required'
TARGET_DISK_1=$(readlink -f "$TARGET_DISK_1")
TARGET_DISK_2=$(readlink -f "$TARGET_DISK_2")
[[ "$TARGET_DISK_1" != "$TARGET_DISK_2" ]] || fail 'Target disks must be different'
[[ -d /run/lock ]] || fail '/run/lock is missing'
exec 9>/run/lock/proxmox-auto-install.lock
flock -n 9 || fail 'Another installation holds the lock'

. "$(dirname "${BASH_SOURCE[0]}")/check-disks.sh"
[[ "$CHECK_ONLY" == 1 ]] && { echo 'Preflight passed; QEMU was not started'; exit 0; }

echo "ERASING $TARGET_DISK_1 ($EXPECTED_SERIAL_1) and $TARGET_DISK_2 ($EXPECTED_SERIAL_2)"
echo "Installer firmware: $FIRMWARE_MODE"
# The monitor is a private Unix socket. No VNC or management port is published.
exec qemu-system-x86_64 \
    -enable-kvm -cpu host -machine q35 -m 8192 -smp 8 \
    -drive file="$TARGET_DISK_1",format=raw,if=none,id=drive0,cache=none,aio=native \
    -device nvme,drive=drive0,serial="$EXPECTED_SERIAL_1" \
    -drive file="$TARGET_DISK_2",format=raw,if=none,id=drive1,cache=none,aio=native \
    -device nvme,drive=drive1,serial="$EXPECTED_SERIAL_2" \
    -cdrom "$INSTALL_ISO" -boot order=d \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0,mac="$NIC_MAC" \
    -display none -serial file:"$WORK_DIR/installer-serial.log" \
    -monitor unix:"$WORK_DIR/qemu-monitor.sock",server=on,wait=off
