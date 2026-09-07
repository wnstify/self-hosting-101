# Verify the installation and boot the server

Continue here after the installer reports success and `pve-install-qemu.service` is inactive with exit status 0. Legacy BIOS is required at every boot checkpoint. A UEFI result is a failed check: stop and arrange a legacy BIOS boot before continuing. Commands are grouped by the machine on which they run.

## 1. Check both boot partitions in Rescue

Confirm the installer unit is inactive with `SubState=dead` and `ExecMainStatus=0`. Load the reviewed `install.env`, then reread the partition tables on the two approved disks. Do not import the ZFS pool or start QEMU while a boot partition is mounted.

For this NVMe layout, each whole-disk stable path has a `-part2` link for its boot partition. Inspect both read-only:

```bash
(
set -eu
. /tmp/proxmox-auto/install.env
test "$FIRMWARE_MODE" = bios
test ! -d /sys/firmware/efi
test "$(systemctl show pve-install-qemu -p SubState --value)" = dead
test "$(systemctl show pve-install-qemu -p ExecMainStatus --value)" = 0
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

Both disks should have a BIOS boot partition, a VFAT boot partition, and a `zfs_member` partition. Check that both boot partitions contain kernel and initrd files as well as BIOS GRUB. The VFAT partition may be called an EFI System Partition even on this BIOS installation; that label does not mean the server boots in UEFI. The subsequent guest boot tests the installed boot sectors and loader together.

## 2. Boot the installed disks temporarily

In Rescue, check that `GUEST_CIDR`, `GUEST_GATEWAY`, in `install.env` match the answer and `FIRMWARE_MODE=bios` is unchanged. This helper requires a distinct gateway inside an IPv4 subnet of `/30` or larger. A routed `/32` needs an adapted QEMU test network.

Start the verification guest:

```bash
systemd-run --unit=pve-verify-qemu --property=Type=exec \
  /bin/bash -c 'set -eu; set -a; . /tmp/proxmox-auto/install.env; set +a; umask 077; exec /tmp/proxmox-auto/boot-installed-qemu.sh > /tmp/proxmox-auto/verify-boot.log 2>&1'
```

This boots the disks without attaching the installer ISO. It reuses the disk-identity checks and legacy BIOS. SSH is forwarded to `127.0.0.1:2222` on Rescue, with no public forwarded port.

For recovery after a Rescue reboot, copy `boot-installed-qemu.sh`, `check-disks.sh`, and `qemu-screen.py` into a new private work directory and rebuild `install.env` from live serials. Device names may have swapped. The boot helper does not need the installer ISO or erase flag. It always boots using BIOS.

Wait for the guest to boot. Inspect `pve-verify-qemu.service` and use `qemu-screen.py` if SSH does not become available.

The console advertises the host address by default. After the localhost GUI setting below, use the SSH tunnel described in step 8.

## 3. Capture the installed host key through trusted SSH

From your workstation, use the already authenticated Rescue connection to read the key of its local verification guest:

```bash
ssh root@SERVER_IP 'ssh-keyscan -T 10 -t ed25519 -p 2222 127.0.0.1 2>/dev/null'
```

The output starts with `[127.0.0.1]:2222 ssh-ed25519`. Save a local file named `installed-known-hosts` containing that public-key line, replacing the first field with `pve-install-guest,SERVER_IP` and replacing `SERVER_IP` with your actual address. Keep the key type and key data unchanged. This key was obtained through trusted Rescue SSH, not an unauthenticated scan of the public server.

Connect to the installed guest from the workstation:

```bash
ssh -o HostKeyAlias=pve-install-guest \
  -o UserKnownHostsFile=./installed-known-hosts \
  -o StrictHostKeyChecking=yes \
  -J root@SERVER_IP -p 2222 root@127.0.0.1
```

Your workstation's SSH agent authenticates to both hops. Agent forwarding into Rescue is unnecessary.

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

Require BIOS, then confirm the chosen FQDN and network values, both ZFS mirror members online with no errors, both ESPs configured, first-boot success, active Proxmox services, HTTP 200, and working DNS. The `.link` file must match the physical MAC so `nic0` is retained when the system moves from virtual to physical hardware.

The first-boot hook applies sysctl immediately and adds `ipv6.disable=1` for the next boot. Confirm the kernel flag after the physical reboot.

## 5. Set up administrative access

If you chose a password interactively before installation, keep using that password. If an agent discarded the installer password, either run `passwd` yourself over verified SSH or have the agent generate an initial password privately on the installed host:

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

Run the block only when the file is absent; stop if that check fails. The agent should never print the password or hash into a shared transcript. The owner can read the file in their own terminal and save it in a password manager.

For the tutorial deployment, SSH uses keys and the GUI listens only on localhost. Apply these settings inside the installed guest:

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

Confirm a fresh key-based SSH connection succeeds before closing the old one. Expect the GUI to listen on `127.0.0.1:8006` and return HTTP 200. This is a standalone-host access choice; review it before adding a cluster or a reverse proxy that runs on another machine.

## 6. Shut down the guest and reboot the hardware

Inside the installed guest:

```bash
systemctl poweroff
```

In Rescue, wait for `pve-verify-qemu.service` to become inactive. Copy any sanitized evidence you need to your workstation now. The private answer, modified ISO, and temporary logs in Rescue will not survive the physical reboot.

```bash
(
set -eu
test "$(systemctl show pve-verify-qemu -p SubState --value)" = dead
sync
systemctl reboot
)
```

The guest boot verified its disk contents and configuration. The next boot verifies the physical firmware and network. If the server does not return, inspect it through Rescue or a KVM console. Do not rerun the installer or assume the disks need wiping again.

## 7. Verify physical boot and update Proxmox

From the workstation, use the host key captured before reboot:

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

Require `PHYSICAL_BOOT=BIOS`. If it reports UEFI, stop and correct the physical firmware boot setting through the provider console before continuing. Confirm the intended address and gateway, both disks online, and `ipv6.disable=1` in the running kernel command line. The recovery guide is for a diagnosed boot failure, not a mandatory step of a correctly matched installation.

Once verified, update the workstation's normal known-hosts entry for this IP using the public key already captured. `ssh-keygen -R SERVER_IP` removes only the old server entry; append the verified line from `installed-known-hosts` to your normal `~/.ssh/known_hosts`. Plain `ssh root@SERVER_IP` should then work.

From the workstation, copy the update script onto the installed host. Files copied only into Rescue are no longer there:

```bash
scp configure-no-subscription.sh root@SERVER_IP:/root/configure-no-subscription.sh
ssh root@SERVER_IP
```

On Proxmox, use the no-subscription repository if you do not have a subscription:

```bash
sed -i 's/\r$//' /root/configure-no-subscription.sh
chmod 0700 /root/configure-no-subscription.sh
systemd-run --unit=pve-initial-update --property=Type=exec \
  /bin/bash -c 'umask 077; exec /root/configure-no-subscription.sh > /root/pve-initial-update.log 2>&1'
systemctl show pve-initial-update -p ActiveState -p SubState -p ExecMainStatus
tail -20 /root/pve-initial-update.log
```

Wait for successful completion before rebooting. The script is intended for a fresh Debian 13/Proxmox 9 installation with its default repository files. Inspect custom or duplicate repository entries separately. It retains package signature verification and does not remove the subscription notice from the UI.

Check time synchronization on the physical host. If `timedatectl show -p NTPSynchronized` stays `no`, inspect `chronyc -n sources` and `journalctl -u chrony -b`. A source with reach `0` has not returned usable replies. Test a provider time server without changing the clock:

```bash
chronyd -Q -t 10 -f /dev/null 'server ntp1.hetzner.de iburst'
```

If this succeeds while the default sources remain unreachable, add [Hetzner's documented NTP servers](https://docs.hetzner.com/robot/dedicated-server/security/ntp-servers/) to the existing Chrony configuration:

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

Allow time for replies, then require `NTPSynchronized=yes` and a selected source (`^*` in `chronyc -n sources`). If no time server answers, investigate DNS and network filtering instead of treating the check as passed. This fallback was needed in the clean AX41 test.

```bash
systemctl reboot
```

## 8. Final verification and GUI login

Reconnect after reboot and run:

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
test ! -d /proc/sys/net/ipv6 && echo 'IPv6 disabled in the kernel'
systemctl is-active pve-cluster pvedaemon pveproxy pvestatd
systemctl --failed --no-pager
curl -kfsS -o /dev/null -w '%{http_code}\n' https://127.0.0.1:8006/
getent ahostsv4 enterprise.proxmox.com
timedatectl status
apt-get -s full-upgrade
)
```

Check the results rather than relying on the last command's exit code. The boot mode must be BIOS, both disks and storage definitions should be active, the updated kernel should be running, both boot partitions should contain it, and APT should have no pending upgrades. Investigate failed services or unsynchronized time before calling the installation complete.

Open an SSH tunnel from your workstation:

```bash
ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
  -L 127.0.0.1:8006:127.0.0.1:8006 root@SERVER_IP
```

Visit `https://localhost:8006` and log in as `root` with the **Linux PAM** realm. The fresh Proxmox certificate is self-signed; the tunnel protects the connection to the SSH-verified server.

If an initial password file was generated, retrieve it only in your own terminal:

```bash
ssh root@SERVER_IP 'cat /root/proxmox-initial-password'
```

Save it in your password manager, set your preferred root password with `passwd`, and remove the initial password file after confirming access. Keep passwords out of tutorial recordings and screenshots.

The chosen FQDN does not create a public DNS record or configure Pangolin. Those remain separate tasks.
