# Tested configuration

On 2026-09-07, the source workflow completed a clean Proxmox installation on a Hetzner AX41 with an AMD Ryzen 5 3600, 64 GB RAM, and two 512 GB NVMe drives in a ZFS mirror.

The test started from blank disks in Linux Rescue. It used the shared scripts to build the unattended installer, install through QEMU/KVM in BIOS mode, and boot the installed disks for verification. The physical server then passed its first boot and another reboot after package updates. No bootloader repair was required.

| Check | Observed result |
|---|---|
| Proxmox / running kernel | 9.2.11 / 7.0.14-15-pve |
| Physical boot | Legacy BIOS |
| Storage | Both ZFS mirror members online, no read/write/checksum errors |
| Boot files | GRUB and updated kernels on both boot partitions |
| Services / packages | No failed services or pending updates |
| SSH | Key-only root access verified |
| GUI | Localhost port 8006; HTTP 200 and root PAM authentication verified |
| Network | Static IPv4 with gateway inside the subnet; physical MAC pinned to nic0 |
| IPv6 | Disabled in the running kernel |
| DNS / time | DNS working; clock synchronized after reboot |
| Workloads | No guests or reverse proxy deployed |

The default time sources did not respond during this test. Hetzner's time servers did, so the [verification guide](verification.md) includes the tested provider-NTP fallback.

After the installation test, the scripts were restricted to legacy BIOS. Local policy tests verify rejection of UEFI and missing or invalid firmware settings. Skill validation, shell syntax checks, and guide link checks passed. The installation scripts were not rerun against the working server after this restriction.

This is evidence for the tested configuration, not a guarantee for every server. Other hardware, storage layouts, Intel microcode selection, routed /32 networking, and booting after a disk failure need their own validation. UEFI is outside this guide's supported workflow.

This summary omits deployment addresses, disk serials, SSH keys, credentials, and raw logs. Keep each new deployment's private evidence in the git-ignored records directory.
