# Tested configuration

On 2026-09-07, the installation workflow completed a clean Proxmox installation on a Hetzner AX41 with an AMD Ryzen 5 3600, 64 GB RAM, and two 512 GB NVMe drives in a ZFS mirror.

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

An earlier attempt, before this test, installed with UEFI firmware in QEMU on a server that boots in legacy BIOS. The server did not boot. That attempt was not recorded in detail, and it is the reason the workflow now requires BIOS everywhere.

## Changes since the live test

Everything below was checked locally only. The installation scripts have not been rerun against a server since the test above.

- Same day, after the test: the launchers were restricted to legacy BIOS. Local policy tests confirm they reject UEFI and missing or invalid firmware settings. Shell syntax checks and link checks passed.
- Same day, review: the verification guide separated the installer-unit check from the reusable disk inspection, added the disk checks and lock before mounting boot partitions, and made the final IPv6 check stop on failure. The credential helper now validates each SSH public key before prompting for a password. Five local regression tests cover it with synthetic keys and a mocked hash.
- 2026-09-07, second review: the erase flag now has to name both approved serials instead of `YES`. The builder refuses an answer whose MAC filter and `nic0` mapping do not match `NIC_MAC` in `install.env`, and refuses the documentation network values. The long-running systemd units keep their result with `RemainAfterExit=yes` so a finished unit can be told apart from one that never ran. The first-boot hook marks its sysctl keys optional so they stop logging errors after IPv6 is disabled in the kernel. The live refusal test gained cases for a legacy `YES` flag and a flag for other serials.

Local tests pass on Windows with Python 3.14 and Git Bash. They do not replace Proxmox answer validation or a live installation.

## Not tested

Other providers, other hardware, other storage layouts, Intel microcode selection, routed `/32` networking, an IPv6-enabled configuration, a host with a Proxmox subscription, boot repair, and booting after a disk failure. UEFI is outside this guide's supported workflow.

This summary omits deployment addresses, disk serials, SSH keys, credentials, and raw logs. Each deployment's private evidence stays in the git-ignored `records/` directory at the repository root.
