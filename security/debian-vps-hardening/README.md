# Harden a Debian 13 VPS

Turn a fresh Debian 13 VPS into a server you log in to with a key only: an admin user with sudo, no root login over SSH, no passwords, a host firewall, and automatic security updates. People and AI agents follow the same scripts and checks. The NetBird and Pangolin servers in this series start from here.

[Security](../README.md) · [Episode index](../../episodes/README.md)

| Detail | Value |
|---|---|
| Status | Draft |
| Video | Recording, as part of the [self-hosted NetBird](../../networking/netbird-selfhosted/README.md) episode |
| Last live test | Not yet for these scripts. The same steps ran by hand on a Hetzner CPX12 on 2026-10-20, see [tested configuration](tested-configuration.md) |
| Materials | None yet |

## What this guide does

You end up with:

- all packages updated;
- an admin user, `ADMIN_USER`, in the sudo group, with your SSH key;
- passwordless sudo for that user, or sudo with a password if you choose it;
- SSH that refuses root, refuses passwords and keyboard-interactive codes, and accepts keys only;
- ufw allowing SSH first, then the ports you name, and blocking all other inbound traffic;
- Debian's automatic security updates switched on.

Tested on Debian 13 on a Hetzner Cloud VPS, IPv4 only. The scripts refuse other releases. Other providers should work but need their own validation.

**Do every step with your root session still open.** The lock phase only runs after you log in as the admin user in a second session. If something goes wrong, the open root session is your way back. Your provider's web console is the second way back.

**Passwordless sudo means your SSH key is all that guards root.** That is fine when the key needs your approval each time, such as a key in a password manager's SSH agent or a hardware key. If your key is a plain file on your disk, use `SUDO_MODE=password`.

Where commands run: **workstation** is your own computer, **server** is the VPS. Copy this directory to the server first (step 2).

## 1. Log in as root

On the workstation, with the key you added when creating the server:

```bash
ssh root@SERVER
```

The first connection asks you to trust the server's host key. It is a brand-new server you just created, so answering `yes` is safe here. Expected: a root prompt. If the login asks for a password, the key was not added at creation; fix that in the provider panel before you continue.

## 2. Copy the scripts to the server

On the workstation, from the repository root:

```bash
scp -r security/debian-vps-hardening root@SERVER:/root/
```

## 3. Create the admin user

On the server, as root:

```bash
cd /root/debian-vps-hardening
ADMIN_USER=alice ./harden.sh user
```

Replace `alice` with your user name. Add `SUDO_MODE=password` to keep a sudo password; the script then tells you to run `passwd alice`.

The script updates every package, creates the user, adds it to the sudo group, writes `/etc/sudoers.d/alice` and checks it with `visudo` before and after installing it, and copies root's authorized keys to the new user. Expected: it ends with "Next: keep this root session open". It stops without changes if root has no valid key or the sudoers file fails `visudo`.

## 4. Test the new login in a second session

Keep the root session open. In a second terminal on the workstation:

```bash
ssh alice@SERVER
sudo whoami
```

Expected: `root`, with no password prompt (or with one if you chose `SUDO_MODE=password`). Do not continue until this works.

## 5. Lock SSH to keys only

Back in the root session:

```bash
ADMIN_USER=alice CONFIRMED_LOGIN=alice ./harden.sh lock
```

`CONFIRMED_LOGIN` is your statement that step 4 worked; the script refuses without it. It installs `/etc/ssh/sshd_config.d/00-hardening.conf`:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
```

The `00-` prefix matters: sshd keeps the first value it reads, and Debian's `sshd_config` includes this directory before its own settings, so a provider's drop-in such as `50-cloud-init.conf` cannot turn passwords back on. The script runs `sshd -t` before reloading and removes its file if the test fails. Expected: three lines ending in `no`, then "Locked."

## 6. Check from the workstation

```bash
security/debian-vps-hardening/verify-ssh.sh SERVER alice
```

Expected: three `PASS` lines and "All SSH checks passed." Any `FAIL` means keep both sessions open and fix it first.

## 7. Turn on the firewall and check updates

Back in the root session, still in `/root/debian-vps-hardening`. Name the ports your service needs; leave `ALLOW_PORTS` empty for SSH only:

```bash
ALLOW_PORTS="80/tcp 443/tcp" ./harden.sh firewall
```

After this step you can close the root session. From now on you log in as the admin user.

To allow SSH only from your own fixed IPv4 address, add `SSH_ALLOW_FROM=198.51.100.7`. Only do that if the address really is fixed, or you lock yourself out.

The script adds the SSH rule before enabling ufw, then the ports you named, then enables it. Expected: `Status: active`, `Default: deny (incoming), allow (outgoing)`, and your rules. Then it shows `enabled` for unattended-upgrades and both periodic settings set to `"1"`. On Hetzner's Debian 13 image that was already the case.

**ufw does not filter ports that Docker publishes.** Docker writes its own iptables rules for published container ports. If you run Docker on this server, your provider's cloud firewall is the filter that counts for container ports; ufw still guards SSH and anything outside Docker.

## Verify the result

| Check | Command | Expected |
|---|---|---|
| SSH policy | workstation: `verify-ssh.sh SERVER alice` | three `PASS` |
| Effective sshd settings | server: `sudo sshd -T \| grep -Ei '^(permitrootlogin\|passwordauthentication\|kbdinteractiveauthentication) '` | all `no` |
| Sudo file | server: `sudo visudo -c` | every file `parsed OK` |
| Firewall | server: `sudo ufw status verbose` | active, deny incoming, your rules |
| Updates | server: `systemctl is-enabled unattended-upgrades` | `enabled` |
| After a reboot | `sudo reboot`, wait, rerun `verify-ssh.sh` | three `PASS` |

## Recovery

- **Locked out of SSH:** use your provider's web console. Root cannot log in over SSH, but the console is not SSH. If you do not know a root password, use the provider's password reset first (Hetzner: Rescue → Reset root password), then log in on the console and fix or remove `/etc/ssh/sshd_config.d/00-hardening.conf`.
- **ufw blocks SSH:** on the console, `ufw allow 22/tcp`, or `ufw disable` while you fix the rules.
- **Broken sudoers file:** the script checks the file before installing it. If you edited one by hand, use the console as root and run `visudo -c`.

## Maintenance

Security updates install daily. Other updates and reboots for new kernels are yours: `sudo apt update && sudo apt full-upgrade`, then `sudo reboot` when a kernel changed. Rerun `verify-ssh.sh` after major changes to SSH.

## Agent instructions

Read the [root AGENTS.md](../../AGENTS.md) and the [hardening skill](../../skills/harden-debian-vps/SKILL.md). The skill walks through the same three phases. The owner does step 4 and confirms it; an agent never sets `CONFIRMED_LOGIN` on its own.

## References

- `sshd_config(5)`: "For each keyword, the first obtained value will be used."
- [Debian wiki: UnattendedUpgrades](https://wiki.debian.org/UnattendedUpgrades)
- [Docker: packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
