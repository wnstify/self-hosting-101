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

## Scripted run, 2026-10-21

The scripts ran on a second fresh server, hardened first with the hardening guide's scripts (`ALLOW_PORTS="80/tcp 443/tcp 51820/udp 21820/udp"`), driven by an agent over SSH without a terminal, with passwordless sudo through a password-manager SSH agent.

| Item | Value |
|---|---|
| Server | Debian 13.6 x86_64 cloud image, 1921 MB RAM, 38 GB disk, public IPv4, no IPv6; provider and server type not recorded |
| Docker | Docker 29.9.2, Compose v5.6.0, jq 1.7.1 from `shared/docker/install-docker.sh` |
| Pangolin | installer 1.24.0 from the GitHub release, SHA-256 matched; `fosrl/pangolin:1.24.0`, `fosrl/gerbil:1.5.2`, `traefik:v3.7`, `crowdsecurity/crowdsec:latest` |

What passed:

- `preflight.sh`: "Preflight passed." before and after Docker.
- `install-pangolin.sh`: all 14 prompts answered in the expected order in the installer's plain prompt mode; three containers running; a trusted Let's Encrypt certificate within about a minute.
- The setup token, admin account and first organization, done by the owner.
- `install-crowdsec.sh`: four prompts answered; "CrowdSec installed successfully!"; the three changes applied; crowdsec healthy; "CrowdSec is on, with the three defaults changed."
- `verify.sh`: 16 `PASS`, "All Pangolin checks passed." on the first run after CrowdSec.
- `ban-test.sh` from the workstation: 200, 403 while banned, 200 after the ban was lifted; "Ban test passed."

Two bugs found and fixed during this run, both before the installer changed anything:

- `install-pangolin.sh` and `install-crowdsec.sh` checked sudo with `sudo -v`, which asks for a password even for a `NOPASSWD` user when another sudoers entry (Debian's `%sudo` line) has none, and fails without a terminal. They now run `sudo true`.
- The MaxMind pattern in `install-crowdsec.sh` contained `|` inside parentheses, which `run_answered` took as the pattern separator, so the regex was invalid and the installer waited at its first question with the stack down. The pattern is now `the MaxMind (GeoLite2 )?databases`. A pattern must not contain `|`.

Not verified in this run: reboot persistence and the padlock in the owner's browser. The `crowdsec` container publishes `6060/tcp` on all interfaces; Docker bypasses ufw, so the cloud firewall is what keeps it closed.

## Scripted run, 2026-10-21, third fresh server

Same setup as the second run (Debian 13.6 x86_64, 1921 MB RAM, agent over SSH, passwordless sudo). Hardening, preflight, Docker 29.9.2, `install-pangolin.sh` and the admin account passed as before.

`install-crowdsec.sh` failed on its first run: the installer printed its two questions and finished 25 ms after it started, with CrowdSec not installed and `/opt/pangolin` unchanged. The stack stayed down until `docker compose up -d`. The cause was in the answer runner, not the installer: it checked whether the installer was still alive with `kill -0` on the `sudo` process, and from the admin user that fails with "Operation not permitted" while sudo is starting up, because the process is root's by then. The runner took the failure for "exited" and closed the installer's input, so the installer read end-of-file and took every default. It only happens when the first poll lands before the installer prints its first question, which a fake installer under root sudo reproduced in about 3 runs out of 100. The runner now checks the process state with `ps` instead (`child_running` in `lib.sh`), which passed 200 runs out of 200 the same way. The second real run, which happened to start the installer a second later, passed: four answers, the three changes, `verify.sh` 16 `PASS`, and the ban test from the workstation.

## Scripts

Local checks, `tests/test-local.sh`: domain and email validation, the pinned checksum's format, the refusals of both install scripts before any download, the answer runner against a fake installer (answer order, a skipped optional question, an unexpected question stopping the run), the setup token kept out of log excerpts, and the three CrowdSec changes on synthetic files, including the refusals for a custom trusted-proxy list, a placeholder bouncer key and a missing access log.

What the scripts rely on that the manual run did not exercise:

- The installer's plain prompt mode, which it uses when stdin is not a terminal. The answer runner writes each answer only after its question appears, because each prompt reads stdin afresh.
- The installer binary downloaded straight from the 1.24.0 release with its published SHA-256, instead of through `get-installer.sh`.

## Not tested

- Other providers, Debian releases, ARM servers, IPv6.
- The Enterprise Edition, PostgreSQL, SMTP, Podman.
- Updating Pangolin or CrowdSec in place.
- A CrowdSec bouncer for SSH.
