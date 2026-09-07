# Proxmox installation work

This guide installs Proxmox VE on a Hetzner dedicated server through Linux Rescue and QEMU with legacy BIOS. Read the [root rules](../../AGENTS.md), [installation guide](README.md), and [installation skill](../../skills/install-proxmox-hetzner/SKILL.md) before operating on a server. Companion scripts and tests are in this topic directory. Workstation commands in the guide assume this directory is current.

## Scope and authorization

- An inspection request authorizes read-only inventory. Installation requires the user's approval for the exact server and disk serials, plus the intended storage layout and IPv6 policy.
- Existing approval in the conversation remains valid. Do not ask for it again unless the target, serials, or destructive scope changes.
- Prior installation records are evidence, not authorization for another server. Never copy their disk identities, IP addresses, credentials, or SSH keys into a new deployment.
- Scope is Proxmox installation, base networking, storage, updates, and validation. Do not deploy guests, reverse proxies, overlay networks, or additional services without a separate request.

## Operating rules

- Label the environment for each command: workstation, Rescue, temporary installed QEMU guest, or physical Proxmox host.
- Use the shared scripts. Run Bash syntax checks, validate the answer with Proxmox's assistant, then use `CHECK_ONLY=1` before launching the installer.
- Check canonical disk paths, live serials, mounts, swap, RAID/device-mapper holders, and imported ZFS pools. Empty mount output alone does not establish that a disk is unused. Hetzner's `zpool` can be an interactive installer wrapper; check `/sys/module/zfs` before invoking it.
- Never pass a disk simultaneously to QEMU and an imported Rescue pool. Stop on serial mismatches or active holders. Review affected arrays before stopping them; do not issue blanket RAID, swap, or ZFS teardown commands.
- Legacy BIOS is mandatory. Keep FIRMWARE_MODE=bios. Require Rescue, the installed QEMU guest, and the physical host to report BIOS. If UEFI is detected, stop and explain the provider-console/support step needed to configure legacy boot. Do not select OVMF, bypass the guards, or change physical firmware without the appropriate access. QEMU cannot change the physical firmware settings.
- Use one supported path when guiding a nontechnical owner. Collect technical inventory yourself; explain a failed check and the specific next action in plain language.
- Keep long operations under a named systemd unit. After an SSH interruption, inspect the unit and current storage state before retrying. Never automatically rerun the destructive installer after a timeout or failed physical boot.
- Do not disable SSH host-key verification globally. A successful installed-guest test lets you collect the new host public key over the trusted Rescue connection before the physical reboot.

## Credentials and evidence

- Keep `answer.toml`, modified ISOs, initial passwords, raw installation logs, and private SSH keys out of the repository and tool transcripts. Public-key fingerprints and sanitized command results are appropriate evidence.
- Do not trace commands that read credential fields. Validation logs may include secret values on failure; review them privately or extract only the error category.
- Use the user's approved SSH public key. Bitwarden can provide the private key through its SSH agent; exporting it is unnecessary.
- For agent-led installation, `set-answer-credentials.py --random-password` discards the installer password. Provision a usable password over verified SSH and hand it off privately, or have the user run `passwd` themselves. Never claim GUI access is ready without explaining how to obtain/set its password.
- Keep private checkpoints in the git-ignored `records/` directory at the repository root: inventory, source ISO/checksum, validation, installation result, installed-guest checks, physical boot, update/reboot checks, and unresolved issues. Copy evidence off Rescue before reboot.
- Treat claims in the tutorial as tested only when supported by recorded results. Record a failed attempt and its resolution where it explains a required step.
