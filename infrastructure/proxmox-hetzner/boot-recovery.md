# Inspect a failed legacy BIOS boot

Use this when the installed system booted in QEMU but the physical server does not come back. It gets you back into Rescue, restores the tools, and tells you what to look at. It does not repair anything: no tested repair path exists yet, and this guide does not guess at one. Do not rerun `install-qemu.sh` or wipe the disks.

## Return to Rescue

Activate Linux Rescue with the intended SSH key in the provider panel and reset the server. Verify any changed SSH host fingerprint before updating the saved entry. Keep the installed Proxmox host key you captured during verification.

Copy and run `preflight.sh` again with the workstation commands in [installation step 2](README.md#2-collect-the-server-values). Device names can change after a reboot, so identify the approved disks by serial and use their stable by-id paths. Preflight must report `BOOT_MODE=BIOS`. If it reports UEFI, arrange a legacy BIOS boot through the provider console or support before continuing.

## Restore the Rescue work directory

Temporary files, installed packages, and transient systemd units from the previous Rescue session are gone. In Rescue, recreate the private work directory and install what the boot helper needs:

```bash
(
set -eu
install -d -m 0700 /tmp/proxmox-auto
apt-get -o APT::Update::Error-Mode=any update
apt-get install -y qemu-system-x86 python3
)
```

From `infrastructure/proxmox-hetzner/` on the workstation, copy the helpers and the environment template:

```bash
scp boot-installed-qemu.sh check-disks.sh qemu-screen.py install.env.example root@SERVER_IP:/tmp/proxmox-auto/
```

In Rescue, normalize line endings and check syntax:

```bash
(
set -eu
cd /tmp/proxmox-auto
sed -i 's/\r$//' ./*.sh ./*.py ./*.example
chmod 0700 ./*.sh
for script in ./*.sh; do bash -n "$script"; done
test ! -e install.env
cp install.env.example install.env
chmod 0600 install.env
)
```

Stop if a check fails. If `install.env` already exists, review it before changing it. In Rescue, edit `/tmp/proxmox-auto/install.env` with the approved disk identities, live serials, and installed network settings. Keep `FIRMWARE_MODE=bios`. The boot helper needs neither the installer ISO nor an erase flag.

## Inspect the boot files and the installed system

In Rescue, run [the shared disk inspection](verification.md#inspect-the-approved-disks). It confirms no launcher holds the disk lock, checks the live serials and active storage, then mounts each boot partition read-only. Skip the installer-unit check above that block; it belongs to the original Rescue session. Check for a stray QEMU process with `pgrep -a qemu` first, since one started outside the launchers does not hold the lock.

Both disks need BIOS GRUB, a kernel, and an initrd. If a file is missing, record which one and on which disk before changing anything.

Start the installed guest with the verification guide's `pve-verify-qemu` unit and connect with the host key you recorded. Inside the guest, inspect:

```bash
journalctl --list-boots --no-pager
zpool status
proxmox-boot-tool status
ip -4 -br addr
ip -4 route
cat /usr/local/lib/systemd/network/50-pmx-nic0.link
```

Then follow [the installed-guest checks](verification.md#4-check-the-installed-guest). Require BIOS, the expected disk serials and network configuration, and a healthy mirror. If the guest boots but the physical server does not, the difference is in the firmware boot order, the physical NIC, or the console error message. Read the provider console; a successful QEMU boot proves nothing about those.

Shut the guest down cleanly and confirm the unit shows `SubState=exited` before rebooting the hardware.

## Repair

Repair is outside this guide until a repair has been tested and recorded. The usual candidates are the firmware boot order, a boot partition that `proxmox-boot-tool status` reports as missing, or a pool that fails to import. The [Proxmox bootloader documentation](https://pve.proxmox.com/wiki/Host_Bootloader) covers `proxmox-boot-tool` for the second case. Back up the affected boot configuration before any repair, and keep the repair within the scope the owner approved.

## Why the guide requires BIOS

An earlier installation used UEFI in QEMU while the physical server booted in BIOS, and the server did not boot. The details of that attempt were not recorded. The later [clean BIOS installation](tested-configuration.md) passed both physical reboots without repair, so legacy BIOS is mandatory throughout this workflow.
