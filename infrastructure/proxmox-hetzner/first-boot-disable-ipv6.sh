#!/bin/bash
# Runs automatically on the installed system's first boot, embedded in the prepared ISO. Do not run it by hand.
set -euo pipefail

# The leading '-' tells sysctl to ignore these keys once ipv6.disable=1 removes them.
printf '%s\n' \
    '-net.ipv6.conf.all.disable_ipv6 = 1' \
    '-net.ipv6.conf.default.disable_ipv6 = 1' \
    '-net.ipv6.conf.lo.disable_ipv6 = 1' \
    > /etc/sysctl.d/90-disable-ipv6.conf
chmod 0644 /etc/sysctl.d/90-disable-ipv6.conf

if [[ -d /proc/sys/net/ipv6 ]]; then
    sysctl -p /etc/sysctl.d/90-disable-ipv6.conf
fi

configured=0
if [[ -f /etc/kernel/cmdline ]]; then
    if ! grep -qw 'ipv6.disable=1' /etc/kernel/cmdline; then
        sed -i '1 s/$/ ipv6.disable=1/' /etc/kernel/cmdline
    fi
    configured=1
fi

# BIOS installations use GRUB. Keep its settings in sync even when the ZFS
# installation also has /etc/kernel/cmdline for proxmox-boot-tool.
if [[ -f /etc/default/grub ]] && command -v update-grub >/dev/null; then
    install -d -m 0755 /etc/default/grub.d
    printf '%s\n' 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX ipv6.disable=1"' \
        > /etc/default/grub.d/90-disable-ipv6.cfg
    chmod 0644 /etc/default/grub.d/90-disable-ipv6.cfg
    update-grub
    configured=1
fi
[[ "$configured" == 1 ]] || { echo 'No supported kernel command-line configuration found' >&2; exit 1; }
proxmox-boot-tool refresh
