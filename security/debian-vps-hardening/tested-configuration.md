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

## Scripts

`harden.sh`, `verify-ssh.sh` and `lib.sh` were written after that run from the same steps. Local checks only so far:

- `bash -n` on every script.
- `tests/test-lib.sh` for user names, SSH sources, port lists and key detection.

A live run of the scripts on a fresh server is pending. Until then the guide stays Draft.

## Not tested

- Debian releases other than 13, and other distributions (the script refuses them).
- Providers other than Hetzner Cloud.
- IPv6 (the tested server had no IPv6 address).
- `SUDO_MODE=password` and `SSH_ALLOW_FROM` on a live server.
