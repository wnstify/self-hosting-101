# Self-hosted Pangolin rules

These rules add to the [root rules](../../AGENTS.md). Read those first, then the [guide](README.md), the [hardening guide](../../security/debian-vps-hardening/README.md) and the [installation skill](../../skills/install-pangolin-selfhosted/SKILL.md).

## Scope and approval

- The owner creates the project, firewall, SSH key and server, and both DNS records, in their browser. Do not use provider APIs or CLIs for this guide, and do not ask for API tokens.
- Approval covers the exact server address and domain the owner names. A new server or domain needs a new confirmation.
- Scope is hardening, Docker, Pangolin Community Edition, CrowdSec with the three documented changes, and verification. Sites, resources, Newt, clients, the Enterprise Edition, PostgreSQL, SMTP, identity providers and other services need a separate request.
- This server runs Pangolin only. Do not install other services on it.

## Access

- Never make Pangolin the only way into this server. Keep SSH reachable on its public address, and never delete the SSH rule from the cloud firewall or ufw.
- Keep the root session open until `verify-ssh.sh` passes. Never set `CONFIRMED_LOGIN` without the owner's confirmation that their second login worked.

## Installer

- Use `install-pangolin.sh` and `install-crowdsec.sh`. Never pipe `get-installer.sh` into a shell, and never run an installer from `latest`.
- A checksum mismatch stops the run. Do not update the pinned version, checksum or answer sequences without a separate request and a live test.
- Never rerun the installer over an existing `/opt/pangolin`. If a script stops part-way, read its log and report; do not delete `/opt/pangolin` or its volumes without the owner's explicit approval.
- `install-crowdsec.sh` stops the stack with `docker compose down`. If it fails, tell the owner the stack may be down and how to start it again before anything else.
- Do not edit CrowdSec or Traefik configuration beyond the three documented changes. When a script refuses because a file differs from the tested release, report the difference and stop.

## Credentials and records

- The setup token and the admin password are the owner's. Give the owner the command that reads the token; do not run it yourself, and do not enter, generate or store either value.
- `config/config.yml`, `config/traefik/dynamic_config.yml` (the bouncer key) and the installer's `config.tar.gz` hold secrets. Do not print them, copy them into chat, or commit them.
- The ban test bans the owner's own address for one minute. Run `ban-test.sh` only with the owner's yes, and never write that address into chat or records.
- Record in `records/` at the repository root: the server type and region, the domain, preflight output, versions, `verify.sh` and ban test results, and open issues. No IP addresses of the owner's workstation, no secrets.
