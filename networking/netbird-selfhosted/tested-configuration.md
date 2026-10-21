# Tested configuration: self-hosted NetBird

[Guide](README.md)

## Manual run, 2026-10-20

The guide's steps ran by hand while recording episode 3:

| Item | Value |
|---|---|
| Provider | Hetzner Cloud, Falkenstein (fsn1) |
| Server | CPX12, 1 vCPU, 2 GB RAM, public IPv4, no IPv6, backups on |
| Firewall | Hetzner cloud firewall: 22/tcp, ICMP, 80/tcp, 443/tcp, 3478/udp inbound, IPv4 sources |
| Image | Debian 13 (trixie) |
| DNS | Cloudflare, A record `netbird`, DNS only |
| Docker | Docker CE 29.9.1 from Docker's trixie repository, Compose v5.6.0, jq 1.7.1 |
| NetBird | `getting-started.sh` from v0.81.3, SHA-256 `0aee21c20f9731293bec6b0d1fc73cbbca29f03ef626636ed9d0c7d8261c92fc` |
| Images | `netbirdio/netbird-server` (0.81.3, pulled as `latest`), `netbirdio/dashboard` (v2.95.0, pulled as `latest`), `traefik:v3.7.14` |
| Choices | built-in Traefik, NetBird Proxy off, CrowdSec off |

What passed:

- Hardening as recorded in the [hardening tested configuration](../../security/debian-vps-hardening/tested-configuration.md).
- The installer's interactive prompts: domain, reverse proxy 0, email, proxy N. It printed "The NETBIRD_DOMAIN variable cannot be empty." before asking for the domain, which is expected when the variable is unset.
- Images pulled and containers started in about 15 seconds. "NETBIRD SETUP COMPLETE" with open ports 443/tcp, 80/tcp, 3478/udp.
- The setup page at `/setup`: admin account created, sign-in, onboarding screen. The dashboard reported Management v0.81.3 and Dashboard v2.95.0.

## Scripts, live run 2026-10-20

`preflight.sh`, `install-docker.sh`, `install-netbird.sh`, `verify.sh` and `lib.sh` ran on a freshly rebuilt server of the same type, driven by an AI agent with the `install-netbird-selfhosted` skill and recorded for the episode. The agent asked for every input first and the owner approved each SSH connection in the password manager. Creating the admin account is the owner's step; it was covered in the manual run above.

| Item | Value |
|---|---|
| Server | Hetzner CPX12, Debian 13 x86_64, 1.9 GB RAM, 34 GB free disk |
| Docker | Docker CE 29.9.1, Compose v5.6.0, jq 1.7 |
| NetBird | `getting-started.sh` v0.81.3, checksum matched, unattended (`NETBIRD_NON_INTERACTIVE=true`) |
| Images | `netbirdio/netbird-server:0.81.3`, `netbirdio/dashboard:v2.95.0`, `traefik:v3.7.14` |

What passed:

- Hardening through the scripts, as recorded in the [hardening tested configuration](../../security/debian-vps-hardening/tested-configuration.md).
- DNS check from the workstation: local, 1.1.1.1 and 8.8.8.8 returned only the server address, no AAAA record, DNS only on Cloudflare.
- `preflight.sh`: "Preflight passed." with Docker still missing at that point.
- `install-docker.sh` with the admin user in the docker group; `docker compose version` without sudo after logging back in.
- `install-netbird.sh`: checksum matched, "NETBIRD SETUP COMPLETE" with open ports 443/tcp, 80/tcp, 3478/udp.
- `verify.sh`: "All NetBird checks passed." on the first run, 30 seconds after the install.
- From the workstation: HTTPS 200 with a trusted Let's Encrypt certificate, HTTP redirects to HTTPS.
- Two input mistakes were caught before anything changed on the server: a domain that did not exist (DNS check) and a Let's Encrypt email on that same domain.

Local checks: `bash -n` on every script, and `tests/test-local.sh` (name and email validation, the pinned checksum's format, and the installer refusing a placeholder email, a missing email and an unpinned version before any download).

## Not tested

- A reboot of the server, and STUN (3478/udp) reachability from a client.
- Providers other than Hetzner Cloud, ARM servers, IPv6.
- The NetBird Proxy, CrowdSec, external identity providers.
- Updating to a newer NetBird release, and restoring from backup.
- Joining devices to the self-hosted server.
