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

## Scripts

`preflight.sh`, `install-docker.sh`, `install-netbird.sh`, `verify.sh` and `lib.sh` were written after that run from the same steps. The pinned installer is the same file as in the manual run (same SHA-256). They pin the image tags the manual run actually got. Local checks only so far:

- `bash -n` on every script.
- `tests/test-local.sh`: name and email validation, the pinned checksum's format, and the installer refusing a placeholder email, a missing email and an unpinned version before any download.

A live run of the scripts on a fresh server is pending. Until then the guide stays Draft.

## Not tested

- The unattended installer path (`NETBIRD_NON_INTERACTIVE=true`) on a live server.
- Providers other than Hetzner Cloud, ARM servers, IPv6.
- The NetBird Proxy, CrowdSec, external identity providers.
- Updating to a newer NetBird release, and restoring from backup.
- Joining devices to the self-hosted server.
