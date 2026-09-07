#!/bin/bash
# Rescue only: boot the installed physical disks for verification before rebooting hardware.
set -euo pipefail
umask 077
WORK_DIR="${WORK_DIR:-/tmp/proxmox-auto}"
FIRMWARE_MODE="${FIRMWARE_MODE:-}"
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ "$FIRMWARE_MODE" == bios ]] || fail 'Legacy BIOS is mandatory: set FIRMWARE_MODE=bios'
[[ ! -d /sys/firmware/efi ]] || fail 'Rescue is booted in UEFI; configure legacy BIOS boot before continuing'
: "${GUEST_CIDR:?Set the installed IPv4 CIDR}"
: "${GUEST_GATEWAY:?Set the installed IPv4 gateway}"

exec 9>/run/lock/proxmox-auto-install.lock
flock -n 9 || { echo 'Another QEMU installation or verification is running' >&2; exit 1; }
. "$(dirname "${BASH_SOURCE[0]}")/check-disks.sh"
[[ -c /dev/kvm ]] || fail '/dev/kvm is unavailable'
[[ "${NIC_MAC:-}" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || fail 'A valid NIC_MAC is required'
network=$(python3 -c 'import ipaddress,sys
interface = ipaddress.IPv4Interface(sys.argv[1])
gateway = ipaddress.IPv4Address(sys.argv[2])
if gateway not in interface.network or gateway == interface.ip or interface.network.prefixlen > 30:
    sys.exit("This QEMU test requires a distinct gateway inside an IPv4 subnet of /30 or larger")
print(interface.network)' "$GUEST_CIDR" "$GUEST_GATEWAY")
guest_ip=${GUEST_CIDR%/*}
exec qemu-system-x86_64 \
    -enable-kvm -cpu host -machine q35 -m 8192 -smp 8 \
    -drive file="$TARGET_DISK_1",format=raw,if=none,id=drive0,cache=none,aio=native \
    -device nvme,drive=drive0,serial="$EXPECTED_SERIAL_1" \
    -drive file="$TARGET_DISK_2",format=raw,if=none,id=drive1,cache=none,aio=native \
    -device nvme,drive=drive1,serial="$EXPECTED_SERIAL_2" \
    -boot order=c \
    -netdev "user,id=net0,net=$network,host=$GUEST_GATEWAY,hostfwd=tcp:127.0.0.1:2222-$guest_ip:22" \
    -device virtio-net-pci,netdev=net0,mac="$NIC_MAC" \
    -display none -serial file:"$WORK_DIR/installed-serial.log" \
    -monitor unix:"$WORK_DIR/qemu-monitor.sock",server=on,wait=off
