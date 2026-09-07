---
name: install-proxmox-hetzner
description: Install and verify Proxmox VE on a Hetzner dedicated server through Linux Rescue using QEMU with mandatory legacy BIOS. Use for an authorized fresh Proxmox installation or a preflight inspection, including a reproducible installation record. Does not deploy guests or reverse proxies.
---

# Install Proxmox through Hetzner Rescue

Work from a checkout of the self-hosting-101 repository. Read the root `AGENTS.md`, then `infrastructure/proxmox-hetzner/AGENTS.md` and `infrastructure/proxmox-hetzner/README.md`. The executable workflow, companion scripts, and tests live in `infrastructure/proxmox-hetzner/`; use that as the workstation working directory for the guide's commands. Keep private records in `records/` at the repository root. If the skill is copied into a personal skills folder, locate that checkout rather than assuming relative paths still resolve. If only the skill is available, obtain the companion scripts before using this method.

## Establish the target

Confirm the target and permission for read-only inspection before connecting. An IP and root SSH access do not authorize disk erasure. Run `preflight.sh`, read SMART data for the intended disks, and record serials, active storage, IPv4/prefix/gateway, MAC, DNS, Rescue boot mode, RAM, and virtualization availability.

Collect FQDN, contact email, country, timezone, storage layout, IPv6 policy, and the SSH public key to install. Use existing conversation choices. Bind erase authorization to the server and serials; request it once if absent. Never infer authorization from a record of a different deployment.

This skill supports amd64, legacy BIOS, and a two-disk NVMe ZFS mirror with IPv6 disabled. The builder always includes the IPv6-disabling hook. Stop if the owner needs a different IPv6 policy; that configuration requires separate validation. Keep the supplied `FIRMWARE_MODE=bios` setting. Require BIOS in Rescue, the installed guest, and the physical host. The launchers reject UEFI and missing or invalid modes. Do not use OVMF or bypass the checks.

For a nontechnical owner, collect the inventory yourself and explain outcomes in plain language. Do not ask them to choose between BIOS and UEFI. If Rescue reports UEFI, stop before installation and explain that the server must be configured for legacy BIOS through the provider console or support, then booted into Rescue again. Explain that QEMU cannot change the physical firmware. Recheck afterward; do not treat a requested firmware change as completed without evidence.

## Prepare and install

1. Create a private Rescue work directory. Copy the companion scripts, `answer.toml.example`, and `install.env.example`. Normalize shell-script line endings and run the guide's Bash syntax checks. The colonless MAC filter, MAC-to-`nic0` map, and QEMU NIC MAC must describe the same physical interface.
2. Insert the user's public key and a password hash with `set-answer-credentials.py`. The interactive path takes a password without echo. For unattended work, `--random-password` discards the password and requires a later password handoff or reset over SSH.
3. Verify the pinned source ISO against the publisher's HTTPS checksum. `build-installer.sh` builds a Debian 13 chroot, verifies the Proxmox signing-key fingerprint, and validates the answer. Do not replace Rescue's Debian package sources with Proxmox sources.
4. Check the build's exit status and private output ISO. Run `CHECK_ONLY=1` with the approved disk identities. A mount-free disk with active RAID/LVM holders is not ready. Do not bypass a refusal; inspect the underlying state.
5. Start `install-qemu.sh` under the documented systemd unit. Monitor the unit and, where serial output is incomplete, `qemu-screen.py`. The monitor uses a private Unix socket, with no public VNC listener.
6. Wait for an actual successful installation and QEMU exit. Inspect both boot partitions read-only using the BIOS checks. Never infer installation success from an SSH disconnect or QEMU's exit code alone.

## Verify and hand off

Boot the installed disks through `boot-installed-qemu.sh` with a user-mode network matching the installed IPv4 subnet and gateway. The helper requires a distinct gateway inside an IPv4 subnet of `/30` or larger. Routed `/32` networks need an adapted test network and separate validation. SSH is forwarded only to Rescue's `127.0.0.1:2222`.

Capture the guest's host public key through trusted Rescue SSH, then use that verified key for the guest connection and later physical connection. Inspect hostname, ZFS mirror, bootloader, NIC pinning, first-boot service, and key access. Follow the verification guide to configure key-only SSH and localhost GUI access. Confirm a fresh SSH connection before closing the existing one. Provision a GUI password privately if the installer password was discarded. Shut the guest down cleanly and verify QEMU is stopped before rebooting the physical server.

After reboot, verify the physical host reports legacy BIOS, the approved hostname/network, both ZFS members online, and working SSH. Run `configure-no-subscription.sh` if the owner has no subscription. For a subscribed host, retain the subscription repository and review its update procedure separately. After updates, reboot again and check package state, running kernel, both boot partitions, Proxmox services, API response, DNS, time synchronization, IPv6 disablement, and available storage. Investigate failed checks before handoff.

If Chrony's default time sources remain unreachable, follow the provider-NTP test and fallback in the topic's `verification.md`. Require actual synchronization before handoff and check it again after reboot.

If physical boot fails, follow the topic's `boot-recovery.md` through Rescue or a provider console. Do not reinstall or wipe boot partitions automatically. Re-identify disks by serial after every Rescue reboot. A UEFI result is a failed check; explain what needs correcting rather than switching workflows.

Finish the installation record and tutorial with the tested commands and actual outcomes. Report the SSH target, GUI access method, credential handoff, installed version, storage/boot result, and any remaining limitation. Keep reverse-proxy and guest deployment outside this workflow.
