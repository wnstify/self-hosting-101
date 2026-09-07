#!/bin/bash
# Physical Proxmox host only. Turns off cluster services a standalone host never uses.
# Set DISABLE_SUBSCRIPTION_NAG=1 to also patch the GUI reminder; read the guide first.
set -euo pipefail

DISABLE_SUBSCRIPTION_NAG="${DISABLE_SUBSCRIPTION_NAG:-0}"
WIDGET_JS=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

[[ "${EUID}" -eq 0 ]] || { echo 'Run as root' >&2; exit 1; }
. /etc/os-release
[[ "${ID:-}" == debian && "${VERSION_ID:-}" == 13 ]] || { echo 'Requires Debian 13 / Proxmox 9' >&2; exit 1; }
[[ "$(pveversion)" == pve-manager/9.* ]] || { echo 'Requires Proxmox VE 9' >&2; exit 1; }
# A node in a cluster needs corosync and the HA services. Stopping them there breaks quorum.
[[ ! -f /etc/pve/corosync.conf ]] || { echo 'This host is part of a cluster; leave the HA services running' >&2; exit 1; }
[[ "$(pvecm nodes 2>/dev/null | grep -c '^ ' || true)" -le 1 ]] || { echo 'More than one cluster node is visible; stop and inspect' >&2; exit 1; }

for service in pve-ha-lrm pve-ha-crm corosync; do
    if [[ "$(systemctl is-enabled "$service" 2>/dev/null || true)" == disabled \
       && "$(systemctl is-active "$service" 2>/dev/null || true)" == inactive ]]; then
        echo "$service is already stopped and disabled"
    else
        systemctl disable --now "$service"
        echo "$service stopped and disabled"
    fi
done

if [[ "$DISABLE_SUBSCRIPTION_NAG" == 1 ]]; then
    [[ -f "$WIDGET_JS" ]] || { echo "Missing $WIDGET_JS" >&2; exit 1; }
    if grep -q NoMoreNagging "$WIDGET_JS"; then
        echo 'Subscription reminder is already patched'
    else
        cp -a "$WIDGET_JS" "${WIDGET_JS}.bak-$(date +%F)"
        sed -i -e '/data\.status/ s/!//' -e "/data\.status/ s/active/NoMoreNagging/" "$WIDGET_JS"
        grep -q NoMoreNagging "$WIDGET_JS" || { echo 'Patch did not apply; restore the backup and inspect' >&2; exit 1; }
        systemctl restart pveproxy
        echo 'Subscription reminder patched; a widget-toolkit upgrade reverts it'
    fi
fi

echo 'Single-node configuration complete.'
