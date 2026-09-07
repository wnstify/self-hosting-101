# Proxmox installation rules

These rules add to the [root rules](../../AGENTS.md). Read those first, then the [installation guide](README.md) and the [installation skill](../../skills/install-proxmox-hetzner/SKILL.md). Scripts and tests live in this directory, and the guide's workstation commands assume it is current.

## Approval

- Installation approval covers the exact server, both disk serials, the storage layout, and the IPv6 policy. Ask once. Ask again only if one of those changes.
- The erase flag must name both approved serials. Typing them is not the approval; the owner's confirmation of those serials is.
- A record of a previous deployment is evidence, not approval for another server. Never copy its disk identities, addresses, credentials, or SSH keys into a new deployment.
- Scope is Proxmox, base networking, storage, updates, and validation. Guests, reverse proxies, overlay networks, and other services need a separate request.

## Disks and firmware

- Check by-id paths, live serials, mounts, swap, RAID and device-mapper holders, and imported ZFS pools. Empty mount output alone does not prove a disk is unused.
- Hetzner's `zpool` can be an interactive installer wrapper. Check `/sys/module/zfs` before calling it.
- Never give a disk to QEMU while a Rescue pool has it imported. Stop on a serial mismatch or an active holder. Review an affected array before stopping it; do not issue blanket RAID, swap, or ZFS teardown commands.
- Legacy BIOS is mandatory. Keep `FIRMWARE_MODE=bios`. Require BIOS from Rescue, the installed QEMU guest, and the physical host. On UEFI, stop and explain the provider-console or support step; do not select OVMF, bypass the guards, or claim a firmware change without evidence. QEMU cannot change the physical firmware.

## Running the steps

- Run the Bash syntax checks, let the builder validate the answer, then run `CHECK_ONLY=1` before the destructive launch.
- Keep long operations under the guide's named systemd units. They keep their result after exit; check `SubState` and `ExecMainStatus` rather than assuming success from a closed SSH session.
- After an interruption, inspect the unit and the current storage state before retrying. Never rerun the installer automatically after a timeout or a failed physical boot.
- A successful installed-guest boot lets you collect the new host key over the trusted Rescue connection before the physical reboot. Use it for every later connection.
- With a nontechnical owner, collect the inventory yourself and explain a failed check and its next step in plain language. Do not ask them to choose between BIOS and UEFI.

## Credentials and records

- Do not trace commands that read credential fields. Validation logs can contain secrets on failure; read them privately and report only the error category.
- With `set-answer-credentials.py --random-password`, the installer password is gone. Set a usable password over verified SSH and hand it off privately, or have the owner run `passwd`. Never claim GUI access is ready without saying how the owner gets the password.
- Record in `records/` at the repository root: inventory, source ISO and checksum, validation result, installation result, installed-guest checks, physical boot, update and reboot checks, and open issues. Copy evidence off Rescue before rebooting.
- A guide claim counts as tested only when the [tested configuration](tested-configuration.md) records it. Record a failed attempt and its resolution when it explains a required step.
