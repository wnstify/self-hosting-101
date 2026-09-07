#!/bin/bash
# Read-only inventory. Hetzner's zpool may be an installer wrapper, so it runs only when the ZFS module is loaded.
set -eu
hostname
cat /etc/os-release
uname -r
if [[ -d /sys/firmware/efi ]]; then echo BOOT_MODE=UEFI; else echo BOOT_MODE=BIOS; fi
lscpu | head -25
free -h
lsblk -d -o PATH,SIZE,MODEL,SERIAL,TYPE
lsblk -e 1,7 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
findmnt -rn -o SOURCE,TARGET,FSTYPE
swapon --show
cat /proc/mdstat
ip -br link
ip -4 -br addr
ip -4 route
ip -6 -br addr
resolvectl dns || cat /etc/resolv.conf
dmidecode -t bios
ls -l /dev/kvm || echo 'KVM_MISSING: /dev/kvm is absent; the QEMU installer cannot run here'
for cmd in qemu-system-x86_64 debootstrap smartctl; do command -v "$cmd" || true; done
if [[ -d /sys/module/zfs ]]; then zpool status -LP </dev/null; fi
