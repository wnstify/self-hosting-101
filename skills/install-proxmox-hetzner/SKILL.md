---
name: install-proxmox-hetzner
description: Install and verify Proxmox VE on a Hetzner dedicated server through Linux Rescue using QEMU with mandatory legacy BIOS. Use for an authorized fresh Proxmox installation or a preflight inspection, including a reproducible installation record. Does not deploy guests or reverse proxies.
---

# Install Proxmox through Hetzner Rescue

Work from a checkout of the self-hosting-101 repository. Read the root `AGENTS.md`, then `infrastructure/proxmox-hetzner/AGENTS.md` and `infrastructure/proxmox-hetzner/README.md`. The guide, scripts, and tests live in `infrastructure/proxmox-hetzner/`; use it as the workstation working directory. Private records go in `records/` at the repository root; create it if it is missing. If this skill was copied into a personal skills folder, locate the checkout instead of assuming relative paths resolve. Without the companion scripts, stop and obtain them.

This skill is a checklist over the guide, not a second procedure. When the two differ, the guide wins.

## Establish the target

Confirm the target and permission for read-only inspection before connecting. An IP and root SSH access do not authorize disk erasure. Run `preflight.sh`, read SMART data for the intended disks, and record serials, active storage, IPv4/prefix/gateway, MAC, DNS, Rescue boot mode, RAM, and KVM availability.

Collect FQDN, contact email, country, timezone, storage layout, IPv6 policy, and the SSH public key to install. Use choices already made in the conversation. Bind erase authorization to the server and both serials; request it once if absent. Never infer authorization from a record of a different deployment.

This skill supports amd64, legacy BIOS, and a two-disk NVMe ZFS mirror with IPv6 disabled. The builder always includes the IPv6-disabling hook. Stop if the owner needs a different IPv6 policy; that configuration has not been validated. Keep `FIRMWARE_MODE=bios`. Require BIOS in Rescue, the installed guest, and the physical host. The launchers reject UEFI and missing or invalid modes. Do not use OVMF or bypass the checks.

For a nontechnical owner, collect the inventory yourself and explain outcomes in plain language. Do not ask them to choose between BIOS and UEFI. If Rescue reports UEFI, stop before installation and explain that the server must be set to legacy BIOS through the provider console or support, then booted into Rescue again. QEMU cannot change the physical firmware. Recheck afterwards; do not treat a requested firmware change as done without evidence.

## Prepare and install

1. Create a private Rescue work directory. Copy the companion scripts, `answer.toml.example`, and `install.env.example`. Normalize line endings for every copied file and run the guide's Bash syntax checks. The colonless MAC filter, the MAC-to-`nic0` map, and `NIC_MAC` must describe the same physical interface; the builder refuses a mismatch.
2. Insert the user's public key and a password hash with `set-answer-credentials.py`. The interactive path takes a password of at least 16 characters without echo. For unattended work, `--random-password` discards the password and requires a later handoff or reset over SSH.
3. Verify the pinned source ISO against the publisher's HTTPS checksum. `build-installer.sh` builds a Debian 13 chroot, verifies the Proxmox signing-key fingerprint, and validates the answer. Do not replace Rescue's Debian package sources with Proxmox sources.
4. Check the build unit's `SubState=exited` and `ExecMainStatus=0` and confirm the private output ISO exists. Run `CHECK_ONLY=1` with the approved disk identities and the serial-bound erase flag. A mount-free disk with active RAID or LVM holders is not ready. Do not bypass a refusal; inspect the state behind it.
5. Start `install-qemu.sh` under the guide's systemd unit. Monitor the unit and, where serial output is incomplete, `qemu-screen.py`. The monitor uses a private Unix socket with no public VNC listener.
6. Wait for the unit to show `exited` with status 0. Inspect both boot partitions read-only with the BIOS checks. Never infer success from an SSH disconnect or a unit that shows `dead`; a unit that never ran shows `dead` too.

## Verify and hand off

Boot the installed disks through `boot-installed-qemu.sh` with a user-mode network matching the installed IPv4 subnet and gateway. The helper requires a distinct gateway inside an IPv4 subnet of `/30` or larger. Routed `/32` networks need an adapted test network and separate validation. SSH is forwarded only to Rescue's `127.0.0.1:2222`.

Capture the guest's host public key through trusted Rescue SSH, then use that key for the guest connection and the later physical connection. Inspect hostname, ZFS mirror, bootloader, NIC pinning, first-boot service, and key access. Follow the verification guide to configure key-only SSH and localhost GUI access. Confirm a fresh SSH connection before closing the existing one. Set a GUI password privately if the installer password was discarded. Shut the guest down cleanly and confirm the unit shows `exited` before rebooting the physical server.

After the reboot, verify that the physical host reports legacy BIOS, the approved hostname and network, both ZFS members online, and working SSH. Run `configure-no-subscription.sh` if the owner has no subscription. A subscribed host is outside this workflow; say so instead of improvising an update path. After updates, reboot again and check package state, running kernel, both boot partitions, Proxmox services, API response, DNS, time synchronization, IPv6 disablement, and available storage. Investigate failed checks before handoff.

If Chrony's default time sources stay unreachable, follow the provider-NTP test and fallback in the topic's `verification.md`. Require actual synchronization before handoff and check it again after the reboot.

If the physical boot fails, follow the topic's `boot-recovery.md` through Rescue or a provider console. It inspects; it does not repair. Do not reinstall or rewrite boot partitions on your own initiative. Re-identify disks by serial after every Rescue reboot. A UEFI result is a failed check; explain what needs correcting rather than switching workflows.

Finish the installation record in `records/` with the commands run and their outcomes. Report the SSH target, GUI access method, credential handoff, installed version, storage and boot result, and any remaining limitation. Editing the public guide is a separate task the owner has to ask for.
