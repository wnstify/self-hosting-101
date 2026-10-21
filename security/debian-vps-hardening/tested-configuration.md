# Tested configuration: Debian VPS hardening

[Guide](README.md)

## Manual run, 2026-10-20

The guide's steps ran by hand, recorded for the self-hosted NetBird episode, on:

| Item | Value |
|---|---|
| Provider | Hetzner Cloud, Falkenstein (fsn1) |
| Server | CPX12, 1 vCPU, 2 GB RAM, IPv4 only |
| Image | Debian 13 (trixie), 13.6 before updates |
| SSH key | ed25519 in a password manager's SSH agent, approval per use |

What passed:

- `apt update && apt upgrade -y` with 53 upgrades and no configuration prompts.
- Admin user creation, `/etc/sudoers.d/<user>` with `NOPASSWD:ALL`, `visudo -c` parsed OK.
- Key copy to the admin user; a second session logged in and `sudo whoami` returned `root`.
- `00-hardening.conf`; `sshd -t`; reload; `sshd -T` showed all three settings `no`. The image had no other drop-in, and before the change it reported `passwordauthentication yes`.
- From the workstation: root login `Permission denied (publickey)`; a login with public keys disabled `Permission denied (publickey)`.
- ufw allowing 22/tcp, 80/tcp, 443/tcp, 3478/udp; enabled with its SSH warning answered; status active, deny incoming.
- unattended-upgrades already installed and enabled on the Hetzner image, both periodic values `"1"`.

## Scripts, live run 2026-10-20

`harden.sh`, `verify-ssh.sh` and `lib.sh` ran on a freshly rebuilt server of the same type, driven by an AI agent with the `harden-debian-vps` skill (called from the NetBird skill) and recorded for the self-hosted NetBird episode. Choices: passwordless sudo, SSH from anywhere, ports 80/tcp, 443/tcp and 3478/udp.

What passed:

- First login as root with a key. Stale `known_hosts` entries for the rebuilt server were removed with `ssh-keygen -R`; the new ed25519 host key was accepted on first connect.
- `harden.sh user`: ended with "Next: keep this root session open". A second login as the admin user, with `sudo -n whoami` returning `root`.
- `harden.sh lock`: three `no` lines and "Locked."
- `verify-ssh.sh` from the workstation: three `PASS` lines.
- `harden.sh firewall`: ufw active with 22/tcp, 80/tcp, 443/tcp and 3478/udp; unattended-upgrades enabled, both periodic values `"1"`.

Local checks: `bash -n` on every script, and `tests/test-lib.sh` for user names, SSH sources, port lists and key detection.

## Not tested

- Debian releases other than 13, and other distributions (the script refuses them).
- Providers other than Hetzner Cloud.
- IPv6 (the tested server had no IPv6 address).
- `SUDO_MODE=password` and `SSH_ALLOW_FROM` on a live server.
- A reboot after hardening.
