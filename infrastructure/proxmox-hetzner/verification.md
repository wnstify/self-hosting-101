# Verify the installation and boot the server

Continue here after the installer unit finished. Legacy BIOS is required at every boot checkpoint. If a check reports UEFI, stop and arrange a legacy BIOS boot before continuing. Each command block names the machine it runs on.

Workstation commands assume `infrastructure/proxmox-hetzner` is your current directory, as in the [installation guide](README.md). Keep the local `installed-known-hosts` file there; Git ignores it. Private deployment evidence goes in `records/` at the repository root.

## 1. Check both boot partitions in Rescue

For the initial installation, confirm in Rescue that the installer unit finished with exit status 0. The unit was started with `RemainAfterExit=yes`, so a successful run shows `exited`; a unit that never ran shows `dead`, and a failed one shows `failed`.

```bash
(
set -eu
test "$(systemctl show pve-install-qemu -p SubState --value)" = exited
test "$(systemctl show pve-install-qemu -p ExecMainStatus --value)" = 0
)
```

This check only works in the Rescue session that ran the installer. After a Rescue reboot the transient unit is gone; follow [inspect a failed boot](boot-recovery.md) to recreate the work directory before using the disk inspection below.

### Inspect the approved disks

In Rescue, confirm that no QEMU process is using either approved disk. The block below takes the launchers' lock and reruns the shared disk checks, so it refuses to continue while a launcher runs or while a serial, mount, holder, or imported pool does not match. A QEMU process started outside the launchers does not hold that lock; check for it with `pgrep -a qemu` first. Stop on any failed check. Do not import the ZFS pool or start QEMU while a boot partition is mounted.

Each `/dev/disk/by-id/` whole-disk link has a `-part2` link for its boot partition. That is why `install.env` must use by-id paths; a plain `/dev/nvme0n1` value has no `-part2` link and the mount fails. Inspect both read-only:

```bash
(
set -euo pipefail
. /tmp/proxmox-auto/install.env
test "$FIRMWARE_MODE" = bios
test ! -d /sys/firmware/efi
exec 9>/run/lock/proxmox-auto-install.lock
flock -n 9 || { echo 'A QEMU operation holds the disk lock; stop and inspect it' >&2; exit 1; }
( . /tmp/proxmox-auto/check-disks.sh )
for disk in "$TARGET_DISK_1" "$TARGET_DISK_2"; do blockdev --rereadpt "$disk"; done
udevadm settle
lsblk -e 1,7 -o NAME,SIZE,FSTYPE,PARTTYPE,MOUNTPOINTS
install -d /mnt/pve-boot
trap 'mountpoint -q /mnt/pve-boot && umount /mnt/pve-boot' EXIT
for disk in "$TARGET_DISK_1" "$TARGET_DISK_2"; do
    mount -o ro "${disk}-part2" /mnt/pve-boot
    test -s /mnt/pve-boot/grub/i386-pc/core.img
    test -s /mnt/pve-boot/grub/grub.cfg
    find /mnt/pve-boot -maxdepth 4 -type f \
        \( -name 'vmlinuz*' -o -name 'initrd*' -o -name 'core.img' -o -name 'grub.cfg' \)
    umount /mnt/pve-boot
done
trap - EXIT
)
```

Both disks should show a BIOS boot partition, a VFAT boot partition, and a `zfs_member` partition, and both boot partitions should contain kernel and initrd files as well as BIOS GRUB. The VFAT partition may be labeled as an EFI System Partition even on this BIOS installation; that label does not mean the server boots in UEFI. The guest boot in the next step tests the boot sectors and loader together.

## 2. Boot the installed disks temporarily

In Rescue, check that `GUEST_CIDR` and `GUEST_GATEWAY` in `install.env` match the answer and that `FIRMWARE_MODE=bios` is unchanged. This helper requires a distinct gateway inside an IPv4 subnet of `/30` or larger. A routed `/32` needs an adapted QEMU test network and separate validation.

Start the verification guest in Rescue:

```bash
systemd-run --unit=pve-verify-qemu --property=Type=exec --property=RemainAfterExit=yes \
  /bin/bash -c 'set -eu; set -a; . /tmp/proxmox-auto/install.env; set +a; umask 077; exec /tmp/proxmox-auto/boot-installed-qemu.sh > /tmp/proxmox-auto/verify-boot.log 2>&1'
```

This boots the disks without the installer ISO, reusing the disk-identity checks and legacy BIOS. It needs no erase flag. SSH is forwarded to `127.0.0.1:2222` on Rescue only. If you need to start the guest a second time in the same Rescue session, run `systemctl stop pve-verify-qemu` first so the unit name is free.

Wait for the guest to boot. Inspect `pve-verify-qemu.service` and use `qemu-screen.py` if SSH does not become available.

The Proxmox login banner prints a GUI address on the server's public IP. Ignore it; after step 5 the GUI listens on localhost only and you reach it through the SSH tunnel in step 8.

## 3. Capture the installed host key through trusted SSH

From your workstation, use the already authenticated Rescue connection to read the host key of the guest running on it:

```bash
ssh root@SERVER_IP 'ssh-keyscan -T 10 -t ed25519 -p 2222 127.0.0.1 2>/dev/null'
```

The output starts with `[127.0.0.1]:2222 ssh-ed25519`. Save that line in a local file named `installed-known-hosts`, replacing the first field with `pve-install-guest,SERVER_IP` and `SERVER_IP` with your actual address. Keep the key type and key data unchanged. The two names let one line serve both the guest connection now and the physical connection after reboot. The key came over trusted Rescue SSH, not from an unauthenticated scan of the public server.

Connect to the installed guest from the workstation:

```bash
ssh -o HostKeyAlias=pve-install-guest \
  -o UserKnownHostsFile=./installed-known-hosts \
  -o StrictHostKeyChecking=yes \
  -J root@SERVER_IP -p 2222 root@127.0.0.1
```

Your workstation's SSH agent authenticates both hops. Agent forwarding into Rescue is unnecessary.

## 4. Check the installed guest

Run inside the installed guest:

```bash
(
set -eu
hostname -f
pveversion
if test -d /sys/firmware/efi; then
    echo 'ERROR: legacy BIOS is required; stop and correct the boot mode' >&2
    exit 1
fi
echo BIOS
zpool status
proxmox-boot-tool status
ip -4 -br addr
ip -4 route
cat /etc/network/interfaces
cat /usr/local/lib/systemd/network/50-pmx-nic0.link
if test -f /etc/kernel/cmdline; then cat /etc/kernel/cmdline; fi
if test -f /etc/default/grub.d/90-disable-ipv6.cfg; then cat /etc/default/grub.d/90-disable-ipv6.cfg; fi
systemctl show proxmox-first-boot -p Result -p ExecMainStatus
systemctl is-active pve-cluster pvedaemon pveproxy pvestatd
curl -kfsS -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8006/
getent ahostsv4 enterprise.proxmox.com
timedatectl status
)
```

Require BIOS, then confirm the chosen FQDN and network values. Both ZFS mirror members must be online without errors, and both boot partitions must be configured. Check first-boot success, active Proxmox services, HTTP 200, and working DNS. The `.link` file must carry the physical MAC so the physical interface keeps the name `nic0`.

The first-boot hook applies sysctl immediately and adds `ipv6.disable=1` for the next boot. Confirm the kernel flag after the physical reboot.

## 5. Set up administrative access

If you chose a password interactively before installation, keep using it. If an agent discarded the installer password, run `passwd` yourself over verified SSH inside the installed guest. Or let the agent generate an initial password privately inside that guest:

```bash
(
set -eu
umask 077
test ! -e /root/proxmox-initial-password
openssl rand -base64 30 > /root/proxmox-initial-password
printf 'root:%s\n' "$(cat /root/proxmox-initial-password)" | chpasswd
chmod 0600 /root/proxmox-initial-password
)
```

Run the block only when the file is absent; stop if that check fails. The agent must never print the password or hash into a shared transcript. You read the file in your own terminal and save it in a password manager.

For this deployment, SSH uses keys only and the GUI listens on localhost. Apply these settings inside the installed guest:

```bash
(
set -eu
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n' \
  > /etc/ssh/sshd_config.d/00-proxmox-key-only.conf
sshd -t
systemctl reload ssh
printf 'LISTEN_IP=127.0.0.1\n' > /etc/default/pveproxy
systemctl restart pveproxy
ss -lntp | grep ':8006 '
curl -kfsS -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8006/
)
```

Open a fresh key-based SSH connection and confirm it works before closing the old one. Expect the GUI to listen on `127.0.0.1:8006` and return HTTP 200. This is a standalone-host choice; revisit it before adding a cluster or a reverse proxy on another machine.

## 6. Shut down the guest and reboot the hardware

Inside the installed guest:

```bash
systemctl poweroff
```

In Rescue, wait for the verification unit to finish. Copy any sanitized evidence you need to your workstation now; the private answer, modified ISO, and logs in Rescue do not survive the physical reboot.

```bash
(
set -eu
test "$(systemctl show pve-verify-qemu -p SubState --value)" = exited
sync
systemctl reboot
)
```

The guest boot verified the disk contents and configuration. The physical boot verifies the firmware and network. If the server does not return, inspect it through Rescue or a KVM console using [inspect a failed boot](boot-recovery.md). Do not rerun the installer or assume the disks need wiping again.

## 7. Verify physical boot and update Proxmox

From the workstation, use the host key captured before the reboot:

```bash
ssh -o UserKnownHostsFile=./installed-known-hosts \
  -o StrictHostKeyChecking=yes root@SERVER_IP
```

On the physical Proxmox host:

```bash
(
set -eu
hostname -f
if test -d /sys/firmware/efi; then
    echo 'ERROR: legacy BIOS is required; stop and correct the boot mode' >&2
    exit 1
fi
echo PHYSICAL_BOOT=BIOS
cat /proc/cmdline
zpool status
ip -4 -br addr
ip -4 route
)
```

Require `PHYSICAL_BOOT=BIOS`. If it reports UEFI, stop and correct the boot setting through the provider console before continuing. Confirm the intended address and gateway, both disks online, and `ipv6.disable=1` in the running kernel command line.

Once verified, add the captured key to your normal known-hosts file. `ssh-keygen -R SERVER_IP` removes only the old entry for this address; then append the verified line from `installed-known-hosts` to `~/.ssh/known_hosts`. Plain `ssh root@SERVER_IP` works after that.

From the workstation, copy the update script onto the installed host:

```bash
scp configure-no-subscription.sh root@SERVER_IP:/root/configure-no-subscription.sh
ssh root@SERVER_IP
```

On the physical Proxmox host, switch to the no-subscription repository if you do not have a subscription:

```bash
sed -i 's/\r$//' /root/configure-no-subscription.sh
chmod 0700 /root/configure-no-subscription.sh
systemd-run --unit=pve-initial-update --property=Type=exec --property=RemainAfterExit=yes \
  /bin/bash -c 'umask 077; exec /root/configure-no-subscription.sh > /root/pve-initial-update.log 2>&1'
systemctl show pve-initial-update -p ActiveState -p SubState -p ExecMainStatus
tail -20 /root/pve-initial-update.log
```

Wait for `SubState=exited` with `ExecMainStatus=0` before rebooting. The script expects a fresh Debian 13 and Proxmox 9 installation with its default repository files. Inspect custom or duplicate repository entries separately. It keeps package signature verification and does not remove the subscription notice from the UI. A host with a subscription keeps its enterprise repository and updates through the standard Proxmox procedure instead; that path is not covered here.

Check time synchronization on the physical Proxmox host. If `timedatectl show -p NTPSynchronized` stays `no`, inspect `chronyc -n sources` and `journalctl -u chrony -b`. A source with reach `0` has not returned usable replies. On the physical Proxmox host, test a provider time server without changing the clock:

```bash
chronyd -Q -t 10 -f /dev/null 'server ntp1.hetzner.de iburst'
```

If this succeeds while the default sources stay unreachable, add [Hetzner's documented NTP servers](https://docs.hetzner.com/robot/dedicated-server/security/ntp-servers/) to the existing Chrony configuration. On the physical Proxmox host:

```bash
(
set -eu
install -d -m 0755 /etc/chrony/sources.d
printf '%s\n' \
  'server ntp1.hetzner.de iburst' \
  'server ntp2.hetzner.com iburst' \
  'server ntp3.hetzner.net iburst' \
  > /etc/chrony/sources.d/hetzner.sources
chmod 0644 /etc/chrony/sources.d/hetzner.sources
systemctl restart chrony
)
```

Allow time for replies, then require `NTPSynchronized=yes` and a selected source marked `^*` in `chronyc -n sources`. If no time server answers, investigate DNS and network filtering. This fallback was needed in the AX41 test.

After the update and time checks pass, reboot the physical Proxmox host:

```bash
systemctl reboot
```

## 8. Final verification and GUI login

Reconnect after the reboot and run on the physical Proxmox host:

```bash
(
set -eu
hostname -f
pveversion
uname -r
if test -d /sys/firmware/efi; then
    echo 'ERROR: legacy BIOS is required; stop and correct the boot mode' >&2
    exit 1
fi
echo BIOS
proxmox-boot-tool status
zpool status
pvesm status
ip -4 -br addr
ip -4 route
cat /proc/cmdline
if test -d /proc/sys/net/ipv6; then
    echo 'ERROR: IPv6 is still enabled; stop and inspect the first-boot settings' >&2
    exit 1
fi
echo 'IPv6 disabled in the kernel'
systemctl is-active pve-cluster pvedaemon pveproxy pvestatd
systemctl --failed --no-pager
curl -kfsS -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8006/
getent ahostsv4 enterprise.proxmox.com
timedatectl status
apt-get -s full-upgrade
)
```

Read the results rather than trusting the last exit code. The boot mode must be BIOS, both disks and storage definitions active, the updated kernel running and present on both boot partitions, and APT without pending upgrades. Investigate failed services or unsynchronized time before calling the installation complete.

Open an SSH tunnel from your workstation:

```bash
ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
  -L 127.0.0.1:8006:127.0.0.1:8006 root@SERVER_IP
```

Visit `https://localhost:8006` and log in as `root` with the `Linux PAM` realm. The fresh Proxmox certificate is self-signed; the tunnel protects the connection to the SSH-verified server.

If an initial password file was generated, read it only in your own workstation terminal:

```bash
ssh root@SERVER_IP 'cat /root/proxmox-initial-password'
```

Save it in your password manager, set your preferred root password with `passwd`, and remove the file after confirming access. Keep passwords out of recordings and screenshots.

The chosen FQDN does not create a public DNS record or configure Pangolin. Those are separate tasks.
