#!/bin/bash
# Source this file under set -euo pipefail before exposing physical disks to QEMU.
fail() { echo "ERROR: $*" >&2; exit 1; }
[[ ${EUID} -eq 0 ]] || fail 'Run as root'
: "${TARGET_DISK_1:?Both target disks are required}"
: "${TARGET_DISK_2:?Both target disks are required}"
: "${EXPECTED_SERIAL_1:?Expected disk serial 1 is required}"
: "${EXPECTED_SERIAL_2:?Expected disk serial 2 is required}"
TARGET_DISK_1=$(readlink -f "$TARGET_DISK_1")
TARGET_DISK_2=$(readlink -f "$TARGET_DISK_2")
[[ "$TARGET_DISK_1" != "$TARGET_DISK_2" ]] || fail 'Target disks must be different'
zfs_status=''
if [[ -d /sys/module/zfs ]]; then
    command -v zpool >/dev/null || fail 'ZFS is loaded but zpool is unavailable'
    zfs_status=$(zpool status -LP) || fail 'Cannot inspect imported ZFS pools'
fi
check_disk() {
    local disk="$1" expected="$2" actual node name mounts nodes
    [[ -b "$disk" ]] || fail "Not a block device: $disk"
    [[ "$(lsblk -dnro TYPE "$disk")" == disk ]] || fail "Not a whole disk: $disk"
    [[ "$expected" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'Expected serial is missing or unsupported'
    actual=$(lsblk -dnro SERIAL "$disk" | tr -d '[:space:]')
    [[ "$actual" == "$expected" ]] || fail "Serial mismatch for $disk: expected $expected, found $actual"
    mounts=$(lsblk -nrpo MOUNTPOINTS "$disk")
    [[ ! "$mounts" =~ [^[:space:]] ]] || fail "A filesystem or swap on $disk is active"
    nodes=$(lsblk -nrpo NAME "$disk")
    [[ -n "$nodes" ]] || fail "Cannot enumerate $disk"
    while read -r node; do
        name=${node##*/}
        if compgen -G "/sys/class/block/$name/holders/*" >/dev/null; then
            fail "$node has active holders (RAID, LVM, or device mapper); inspect and release them first"
        fi
        # Hetzner's zpool command can be an interactive installer wrapper.
        if grep -Fq -- "$node " <<< "$zfs_status"; then
            fail "$node belongs to an imported ZFS pool"
        fi
    done <<< "$nodes"
    echo "Verified $disk serial $actual; no mounts, swap, or active holders detected"
}
check_disk "$TARGET_DISK_1" "$EXPECTED_SERIAL_1"
check_disk "$TARGET_DISK_2" "$EXPECTED_SERIAL_2"
