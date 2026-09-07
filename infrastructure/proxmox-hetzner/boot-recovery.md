# Troubleshoot a failed legacy BIOS boot

Legacy BIOS is the only supported boot mode for this guide. If the physical server does not return after installation, inspect the existing installation. Do not rerun `install-qemu.sh` or wipe disks.

## Return to Rescue

Activate Linux Rescue with the intended SSH key in the provider panel and reset the server. Verify any changed SSH host fingerprint before updating the saved entry. Keep the installed Proxmox host key recorded during verification.

Run `preflight.sh` again. Device names can change after a reboot, so identify the approved disks by serial and use their stable by-id paths. Check that Rescue reports BIOS. If it reports UEFI, arrange a legacy BIOS boot through the provider console or support before continuing.

## Inspect the boot files and installed system

Follow the read-only boot-partition checks in [verification](verification.md). Both disks need BIOS GRUB, kernel, and initrd files. If a file is missing, record the failure and investigate before modifying anything.

Recreate the private Rescue work directory and reviewed `install.env`, keeping `FIRMWARE_MODE=bios`. Copy `boot-installed-qemu.sh`, `check-disks.sh`, and `qemu-screen.py` from the checkout's `infrastructure/proxmox-hetzner/` directory. The boot helper requires neither the installer ISO nor an erase flag.

Start the installed guest using the verification guide's systemd unit and connect using its previously recorded SSH host key. Inside the guest, inspect:

```bash
journalctl --list-boots --no-pager
zpool status
proxmox-boot-tool status
ip -4 -br addr
ip -4 route
cat /usr/local/lib/systemd/network/50-pmx-nic0.link
```

Require BIOS, the expected disk serials and network configuration, and a healthy mirror. If the guest boots but the physical server does not, inspect the physical console for the boot order and error message. A successful QEMU boot does not verify the physical firmware settings or network interface.

Shut down the guest cleanly and confirm its QEMU unit has stopped before rebooting the hardware. Diagnose a missing bootloader or failed pool import from the observed error, and back up the affected boot configuration before a repair. This guide does not prescribe a blind repair command.

## Why the guide requires BIOS

An earlier installation used UEFI in QEMU while the physical server booted in BIOS. The later [clean BIOS installation test](tested-configuration.md) passed both physical reboots without repair. Legacy BIOS is mandatory throughout this workflow.
