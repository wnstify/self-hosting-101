#!/bin/bash
set -euo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "Run as root" >&2; exit 1; }
. /etc/os-release
[[ "${ID:-}" == debian && "${VERSION_ID:-}" == 13 ]] || { echo 'Requires Debian 13 / Proxmox 9' >&2; exit 1; }
[[ "$(pveversion)" == pve-manager/9.* ]] || { echo 'Requires Proxmox VE 9' >&2; exit 1; }
case "$(awk -F ': ' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo)" in
    AuthenticAMD) microcode_package=amd64-microcode ;;
    GenuineIntel) microcode_package=intel-microcode ;;
    *) echo 'Unsupported CPU vendor for this amd64 update helper' >&2; exit 1 ;;
esac

printf '%s\n' \
    'Enabled: no' \
    'Types: deb' \
    'URIs: https://enterprise.proxmox.com/debian/pve' \
    'Suites: trixie' \
    'Components: pve-enterprise' \
    'Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg' \
    > /etc/apt/sources.list.d/pve-enterprise.sources

printf '%s\n' \
    'Enabled: no' \
    'Types: deb' \
    'URIs: https://enterprise.proxmox.com/debian/ceph-squid' \
    'Suites: trixie' \
    'Components: enterprise' \
    'Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg' \
    > /etc/apt/sources.list.d/ceph.sources

printf '%s\n' \
    'Types: deb' \
    'URIs: http://download.proxmox.com/debian/pve' \
    'Suites: trixie' \
    'Components: pve-no-subscription' \
    'Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg' \
    > /etc/apt/sources.list.d/pve-no-subscription.sources

apt-get -o APT::Update::Error-Mode=any update
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y "$microcode_package"
proxmox-boot-tool refresh

echo "Update complete. Reboot to activate the latest kernel and microcode."
