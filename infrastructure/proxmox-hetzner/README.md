# Install Proxmox VE on Hetzner

Install Proxmox VE on a Hetzner dedicated server using legacy BIOS. People and AI agents follow the same scripts and checks.

[Infrastructure](../README.md) · [Episode index](../../episodes/README.md) · [Teaching materials](materials/README.md)

This guide is available for the tested configuration below. The first video is being recorded. Companion documents and slides have not been added yet.

For workstation commands, start in this guide's directory. From the repository root, run:

```text
cd infrastructure/proxmox-hetzner
```

The file-transfer commands below assume this working directory. On a Windows workstation, run multiline Bash blocks in Git Bash, or enter the individual commands in your shell's syntax. Commands labeled Rescue or Proxmox run in Bash on that server.

## Install Proxmox VE through Rescue

Install Proxmox from the official ISO over SSH, using QEMU/KVM to expose two physical NVMe disks to the installer. The temporary VM uses legacy BIOS. After installation, the dedicated server boots directly from those disks.

This guide covers Proxmox, a ZFS mirror, host networking, updates, and verification. Pangolin and guest workloads are outside this guide. See the [tested configuration](tested-configuration.md) for validation results and supported scope.

On 2026-09-07, a clean BIOS installation on a Hetzner AX41 passed the installed-guest boot, physical boot, and post-update reboot. It ran Proxmox 9.2.11 and kernel 7.0.14-15-pve with a healthy two-NVMe ZFS mirror. No bootloader recovery was needed. The test also verified key-only SSH, localhost GUI authentication, disabled IPv6, working DNS, synchronized time, and zero pending updates.

**Legacy BIOS is mandatory** for Rescue, the temporary QEMU guest, and the physical Proxmox server. Keep the example's `FIRMWARE_MODE=bios` setting. Both launchers reject UEFI and missing or invalid settings. They also stop if Rescue itself booted in UEFI.

The tested configuration is an AMD AX41 with two NVMe drives and a gateway inside the IPv4 subnet. Other hardware, storage layouts, Intel microcode selection, and routed `/32` networks require their own validation.

If an agent is doing the installation, ask it to follow the [installation skill](../../skills/install-proxmox-hetzner/SKILL.md). It should collect the server details and check the boot mode for you. If the server is in UEFI mode, it must stop and explain how to arrange a legacy BIOS boot through the provider's console or support. Starting QEMU cannot change the physical firmware settings.

**The installation erases both selected disks.** Read the serials from the target server and confirm that all their data can be lost. RAID1 provides redundancy, not an independent backup.

## 1. Activate Rescue and connect

In Hetzner Robot, activate Linux Rescue for the server and select your SSH public key. Reboot into Rescue. Keep Robot available in case you need another Rescue boot or a KVM console.

On your workstation, replace `SERVER_IP` with the actual address:

```bash
ssh root@SERVER_IP
```

If you use Bitwarden's SSH agent, unlock it and approve access to the intended key. Do not export or send the private key to the server.

The server host key may change between Debian, Rescue, and Proxmox. Verify a changed fingerprint through a trusted path before replacing a saved entry. After verification, remove only this server's old entry with `ssh-keygen -R SERVER_IP`. Do not disable host-key checking globally.

## 2. Collect the server values

From this guide's directory on your workstation:

```bash
scp preflight.sh root@SERVER_IP:/root/preflight.sh
ssh root@SERVER_IP 'bash /root/preflight.sh'
```

In Rescue, read the health of each intended drive. Replace these device paths with the ones identified by preflight:

```bash
smartctl -H -A /dev/nvme0n1
smartctl -H -A /dev/nvme1n1
```

Record these values before continuing. Run the inventory commands in Rescue:

| Value | Where to get it |
|---|---|
| Disk paths and serials | `lsblk -d -o PATH,SIZE,MODEL,SERIAL` |
| IPv4 and prefix | `ip -4 -br addr`, checked against Robot |
| IPv4 gateway | `ip -4 route`, checked against Robot |
| Physical MAC | `ip -br link` |
| DNS resolvers | `resolvectl dns` |
| Rescue boot mode | Presence of `/sys/firmware/efi` |
| Desired FQDN, email, timezone | Your choices |

Check mounts, swap, `/proc/mdstat`, and disk holders. An existing Debian installation may have active software RAID even when nothing is mounted. Inspect and stop only the affected arrays after approving their destruction. The installer refuses disks with active holders.

Hetzner's `zpool` command may be a wrapper that installs ZFS. Do not invoke it as an inventory command unless ZFS is already loaded. If `/sys/module/zfs` exists, inspect `zpool status -LP`. Review any affected pool before exporting it, and keep it exported while QEMU uses its disks.

## 3. Copy the scripts

Create the working directory in Rescue:

```bash
install -d -m 0700 /tmp/proxmox-auto
```

From this guide's directory on your workstation:

```bash
scp build-installer.sh install-qemu.sh check-disks.sh boot-installed-qemu.sh first-boot-disable-ipv6.sh configure-no-subscription.sh set-answer-credentials.py qemu-screen.py answer.toml.example install.env.example root@SERVER_IP:/tmp/proxmox-auto/
```

Back in Rescue:

```bash
(
set -eu
cd /tmp/proxmox-auto
sed -i 's/\r$//' ./*.sh
chmod 0700 ./*.sh
for script in ./*.sh; do bash -n "$script"; done
cp answer.toml.example answer.toml
cp install.env.example install.env
chmod 0600 answer.toml install.env
)
```

Resolve any syntax error before proceeding. The line-ending conversion handles files copied from Windows.

## 4. Fill in the answer and disk settings

Edit `answer.toml` in Rescue. The example's `192.0.2.10` and `example.com` are documentation values, not a working configuration.

```bash
cd /tmp/proxmox-auto
vi answer.toml
vi install.env
```

In `answer.toml`, replace the FQDN, contact email, country, timezone, IPv4/prefix, gateway, DNS, and both MAC references. For example, MAC `02:00:00:00:00:10` becomes filter `*020000000010`, and the mapping keeps that MAC assigned to `nic0`. The same MAC goes into `install.env` as `NIC_MAC`.

Set stable physical `/dev/disk/by-id/` paths and live serials in `install.env`. Keep `FIRMWARE_MODE=bios`, as supplied in the example. Legacy BIOS is required. Also set `GUEST_CIDR` and `GUEST_GATEWAY` to match `answer.toml` for the installed-guest test. The answer's `nvme0n1` and `nvme1n1` refer to the two NVMe controllers presented inside QEMU; they are not copied blindly from the physical server's device ordering.

Use only the SSH public keys you want on the installed host. If the Rescue authorized-keys file contains exactly those plain public-key lines, run in Rescue:

```bash
python3 set-answer-credentials.py answer.toml /root/.ssh/authorized_keys
```

The helper prompts for a root password twice without echoing it, hashes it with SHA-512 crypt, and inserts the public keys. Store the password in your password manager. The generated answer and ISO both contain its hash and must remain private.

Agents can use `--random-password` to discard the installer password, then set a usable password over verified SSH later. This path was used in the AX41 installation test.

The builder always includes the supplied first-boot hook. It disables IPv6 through sysctl and adds `ipv6.disable=1` to the installed kernel command line. Confirm this policy before building the installer. If you need IPv6, stop here; that configuration needs a separately validated workflow. Kernel-level IPv6 disablement can affect Proxmox firewall backends. Firewall deployment is outside this guide.

## 5. Download and verify the ISO

In Rescue:

```bash
cd /tmp/proxmox-auto
curl -fL --retry 4 --retry-all-errors \
  -o proxmox-ve_9.2-1.iso \
  https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.iso
echo '4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c  proxmox-ve_9.2-1.iso' | sha256sum -c -
```

Expected result: `proxmox-ve_9.2-1.iso: OK`. Check the filename and checksum against the [official download page](https://enterprise.proxmox.com/iso/). If changing versions, update and revalidate the builder, answer schema, and boot workflow together.

## 6. Build the unattended installer

Run in Rescue:

```bash
systemd-run --unit=pve-build-installer --property=Type=exec \
  /bin/bash -c 'umask 077; exec /tmp/proxmox-auto/build-installer.sh > /tmp/proxmox-auto/build.log 2>&1'
```

The builder installs QEMU/KVM prerequisites in Rescue and builds a separate Debian 13 chroot for the Proxmox installation assistant. It verifies the repository signing-key fingerprint and validates the answer file. Its package repository uses the [official signed HTTP repository](https://github.com/proxmox/pve-docs/blob/master/pve-package-repos.adoc); ISO and signing-key downloads use HTTPS.

Monitor it in Rescue:

```bash
systemctl show pve-build-installer -p ActiveState -p SubState -p ExecMainStatus
tail -20 /tmp/proxmox-auto/build.log
```

Continue only when the unit is inactive with `ExecMainStatus=0`, the log reports `Answer validation passed`, and `/tmp/proxmox-auto/proxmox-auto.iso` exists. Treat logs as private; failed validation may include credential fields. Do not publish the modified ISO.

If the build fails, inspect the error and correct it first. After that, use `systemctl reset-failed pve-build-installer` before relaunching the build. A build retry does not erase disks.

## 7. Approve and install

In Rescue, load your reviewed environment:

```bash
(
set -eu
set -a
. /tmp/proxmox-auto/install.env
set +a
ERASE_CONFIRMED=YES CHECK_ONLY=1 /tmp/proxmox-auto/install-qemu.sh
)
```

The preflight must print both expected serials and `Preflight passed; QEMU was not started`. Supplying `ERASE_CONFIRMED=YES` is appropriate only after you have approved the exact disk identities. Agents must obtain that approval from the owner; the environment flag is not a substitute for it.

Start the destructive installation in Rescue:

```bash
systemd-run --unit=pve-install-qemu --property=Type=exec \
  /bin/bash -c 'set -eu; set -a; . /tmp/proxmox-auto/install.env; set +a; export ERASE_CONFIRMED=YES; umask 077; exec /tmp/proxmox-auto/install-qemu.sh > /tmp/proxmox-auto/install.log 2>&1'
```

The prepared ISO selects the automated installer and powers QEMU off when installation succeeds.

![Automated installer selected](images/installer-menu.png)

In Rescue, monitor the unit and capture the QEMU screen when needed:

```bash
systemctl show pve-install-qemu -p ActiveState -p SubState -p ExecMainStatus
python3 /tmp/proxmox-auto/qemu-screen.py
```

Copy `/tmp/proxmox-auto/qemu-screen.ppm` to your workstation to view it. Some installer progress appears only on the graphical console. The helper uses a private Unix socket and does not expose VNC to the Internet.

![Installer package extraction during the BIOS test](images/installer-progress.png)

Do not restart the installer because SSH disconnected or progress stopped changing. Inspect the existing unit first. Repeating this step erases the disks again.

## 8. Verify the installed system

Follow [verification and first boot](verification.md) before rebooting the physical server. It covers both BIOS boot partitions, a temporary installed-guest boot, trusted SSH host-key capture, the physical reboot, updates, and final checks.

If the installed system works in QEMU but the physical server does not boot, use [boot recovery](boot-recovery.md). It covers BIOS boot diagnosis and when to use the provider console.

## Agent instructions

Agents should read the [root rules](../../AGENTS.md), [topic rules](AGENTS.md), and dedicated [install-proxmox-hetzner skill](../../skills/install-proxmox-hetzner/SKILL.md). Keep the skill with this checkout, or copy its directory to your agent's skills folder and point it to the checkout. The skill follows the same scripts and checkpoints as this tutorial. See [using an AI agent](../../USING-AI.md) for a starting prompt.

For local maintenance checks, run these commands from this guide's directory on your workstation. They require Python 3.11 or later, Bash for the firmware tests, and `ssh-keygen` for the credential tests. They use no server access or disks:

```text
python tests/test-firmware-policy.py
python tests/test-answer-credentials.py
```

For live preflight checks, [preflight-refusals.sh](tests/preflight-refusals.sh) tests missing approval, missing/invalid firmware mode, UEFI, duplicate disks, and a wrong serial against a reviewed live configuration. Copy it into `tests/` beneath the Rescue work directory, export the reviewed `install.env` values, and run it with Bash after building the ISO. Every invocation forces `CHECK_ONLY=1`; it does not launch QEMU. These tests supplement the installed-guest and physical-boot checks.

## References

- [Proxmox ISO downloads and checksums](https://enterprise.proxmox.com/iso/)
- [Proxmox automated installation](https://pve.proxmox.com/wiki/Automated_Installation)
- [Proxmox bootloader documentation](https://pve.proxmox.com/wiki/Host_Bootloader)
- [Proxmox package repository source documentation](https://github.com/proxmox/pve-docs/blob/master/pve-package-repos.adoc)
- [Hetzner unattended Proxmox tutorial](https://community.hetzner.com/tutorials/install-proxmox-unattended-hetzner/)
