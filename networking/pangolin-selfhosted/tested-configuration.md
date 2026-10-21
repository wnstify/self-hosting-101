# Tested configuration: self-hosted Pangolin

[Guide](README.md)

## Manual run, 2026-10-20 and 2026-10-21

The guide's steps ran by hand while recording episode 2: the install on 2026-10-20, CrowdSec and the ban test on 2026-10-21. The server was hardened with the same settings the [hardening guide](../../security/debian-vps-hardening/README.md) applies, typed as individual commands.

| Item | Value |
|---|---|
| Provider | Hetzner Cloud |
| Server | Debian 13 (trixie) x86_64, public IPv4, no IPv6 |
| Firewall | Hetzner cloud firewall: 22/tcp, ICMP, 80/tcp, 443/tcp, 51820/udp, 21820/udp inbound, IPv4 sources |
| DNS | Cloudflare, A records `pangolin` and `*.pangolin`, DNS only |
| Docker | Docker CE and the Compose plugin from Docker's trixie repository |
| Pangolin | installer 1.24.0 via `get-installer.sh`, Community Edition, SQLite |
| Images | `fosrl/pangolin:1.24.0`, `fosrl/gerbil:1.5.2`, `traefik:v3.7`, `crowdsecurity/crowdsec:latest` |
| Traefik plugins | Badger v1.7.0, CrowdSec bouncer (`traefik-bouncer`, v1.7.1) |
| Choices | `pangolin.<domain>` as base and dashboard domain, Gerbil on, SMTP off, IPv6 off, MaxMind databases on |

What passed:

- The installer's prompts in its interactive form, and image pulls and container start for `pangolin`, `gerbil` and `traefik`.
- The setup token from the container log, the initial setup page, the admin account, sign-in and the first organization.
- A second installer run with `--crowdsec`, after `docker compose down`: without it the installer stopped with "port 80 is occupied". CrowdSec answers as in the guide; "CrowdSec installed successfully!"; `crowdsec` healthy; `traefik-bouncer` registered.
- The three changes with `sed`, each checked with `grep` before and after, then `docker compose restart traefik crowdsec`.
- The ban test: `curl` from the workstation answered 200, 403 while the workstation's address was banned for one minute, and 200 about 20 seconds after `cscli decisions delete`. The same `curl` run on the server itself kept answering 200 while the workstation was banned, which is why `ban-test.sh` runs on the workstation.

Not verified in this run: the server type and RAM were not recorded here, reboot persistence, and the scripts in this directory.

## Scripts

`preflight.sh`, `install-pangolin.sh`, `install-crowdsec.sh`, `verify.sh`, `ban-test.sh` and `lib.sh` have not had a live run yet. Until they do, the guide stays Draft.

Local checks, `tests/test-local.sh`: domain and email validation, the pinned checksum's format, the refusals of both install scripts before any download, the answer runner against a fake installer (answer order, a skipped optional question, an unexpected question stopping the run), the setup token kept out of log excerpts, and the three CrowdSec changes on synthetic files, including the refusals for a custom trusted-proxy list, a placeholder bouncer key and a missing access log.

What the scripts rely on that the manual run did not exercise:

- The installer's plain prompt mode, which it uses when stdin is not a terminal. The answer runner writes each answer only after its question appears, because each prompt reads stdin afresh.
- The installer binary downloaded straight from the 1.24.0 release with its published SHA-256, instead of through `get-installer.sh`.

## Not tested

- Other providers, Debian releases, ARM servers, IPv6.
- The Enterprise Edition, PostgreSQL, SMTP, Podman.
- Updating Pangolin or CrowdSec in place.
- A CrowdSec bouncer for SSH.
