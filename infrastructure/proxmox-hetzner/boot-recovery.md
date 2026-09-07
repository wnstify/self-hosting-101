# Troubleshoot a failed legacy BIOS boot

Legacy BIOS is the only supported boot mode for this guide. If the physical server does not return after installation, inspect the existing installation. Do not rerun `install-qemu.sh` or wipe disks.

## Return to Rescue

Activate Linux Rescue with the intended SSH key in the provider panel and reset the server. Verify any changed SSH host fingerprint before updating the saved entry. Keep the installed Proxmox host key recorded during verification.

Copy and run `preflight.sh` again using the workstation commands in [installation step 2](README.md#2-collect-the-server-values). Device names can change after a reboot, so identify the approved disks by serial and use their stable by-id paths. Check that Rescue reports BIOS. If it reports UEFI, arrange a legacy BIOS boot through the provider console or support before continuing.

## Restore the Rescue work directory

The previous Rescue session's temporary files, installed packages, and transient systemd units do not survive reboot. In Rescue, recreate the private work directory and install the verification helper's dependencies:

```bash
(
set -eu
install -d -m 0700 /tmp/proxmox-auto
apt-get -o APT::Update::Error-Mode=any update
apt-get install -y qemu-system-x86 python3
)
```

From `infrastructure/proxmox-hetzner/` on the workstation, copy the helpers and environment template:

```bash
scp boot-installed-qemu.sh check-disks.sh qemu-screen.py install.env.example root@SERVER_IP:/tmp/proxmox-auto/
```

In Rescue, normalize the copied scripts and check their syntax:

```bash
(
set -eu
cd /tmp/proxmox-auto
sed -i 's/\r$//' boot-installed-qemu.sh check-disks.sh qemu-screen.py
chmod 0700 boot-installed-qemu.sh check-disks.sh qemu-screen.py
bash -n boot-installed-qemu.sh
bash -n check-disks.sh
test ! -e install.env
cp install.env.example install.env
chmod 0600 install.env
)
```

Stop if a check fails. If `install.env` already exists, review it before changing it. In Rescue, edit `/tmp/proxmox-auto/install.env` using the approved disk identities, live serials, and installed network settings. Keep `FIRMWARE_MODE=bios`. The boot helper requires neither the installer ISO nor an erase flag.

## Inspect the boot files and installed system

Confirm that no QEMU process is using the approved disks and review mounts, swap, RAID/device-mapper holders, and imported ZFS pools. Then run [the shared disk inspection](verification.md#inspect-the-approved-disks) in Rescue. It checks live disk identities and active storage before mounting either boot partition read-only. The initial-installation unit checks above that block apply only to the original Rescue session.

Both disks need BIOS GRUB, kernel, and initrd files. If a file is missing, record the failure and investigate before modifying anything.

Start the installed guest using the verification guide's systemd unit and connect using its previously recorded SSH host key. Inside the guest, inspect:

```bash
journalctl --list-boots --no-pager
zpool status
proxmox-boot-tool status
ip -4 -br addr
ip -4 route
cat /usr/local/lib/systemd/network/50-pmx-nic0.link
```

Follow [the installed-guest checks](verification.md#4-check-the-installed-guest) too. Require BIOS, the expected disk serials and network configuration, and a healthy mirror. If the guest boots but the physical server does not, inspect the physical console for the boot order and error message. A successful QEMU boot does not verify the physical firmware settings or network interface.

Shut down the guest cleanly and confirm its QEMU unit has stopped before rebooting the hardware. Diagnose a missing bootloader or failed pool import from the observed error, and back up the affected boot configuration before a repair. Choose any repair from that diagnosis and the owner's approved scope.

## Why the guide requires BIOS

An earlier installation used UEFI in QEMU while the physical server booted in BIOS. The later [clean BIOS installation test](tested-configuration.md) passed both physical reboots without repair. Legacy BIOS is mandatory throughout this workflow.
