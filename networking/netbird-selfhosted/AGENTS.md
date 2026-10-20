# Self-hosted NetBird rules

These rules add to the [root rules](../../AGENTS.md). Read those first, then the [guide](README.md), the [hardening guide](../../security/debian-vps-hardening/README.md) and the [installation skill](../../skills/install-netbird-selfhosted/SKILL.md).

## Scope and approval

- The owner creates the project, firewall, SSH key and server, and the DNS record, in their browser. Do not use provider APIs or CLIs for this guide, and do not ask for API tokens.
- Approval covers the exact server address and domain the owner names. A new server or domain needs a new confirmation.
- Scope is hardening, Docker, the NetBird server, and verification. Joining devices, policies, the NetBird Proxy, CrowdSec, external identity providers and other services need a separate request.
- This server runs NetBird only. Do not install other services on it.

## Access

- Never make NetBird the only way into this server. Keep SSH reachable on its public address, and never delete the SSH rule from the cloud firewall or ufw.
- Do not install the NetBird client on this server.
- Keep the root session open until `verify-ssh.sh` passes. Never set `CONFIRMED_LOGIN` without the owner's confirmation that their second login worked.

## Installer

- Use `install-netbird.sh`. Never pipe the installer into a shell, and never run `getting-started.sh` from `latest`.
- A checksum mismatch stops the run. Do not update the pinned checksum or version without a separate request and a live test.
- Never rerun the installer over an existing `~/netbird`, and never run the cleanup command it suggests without the owner's explicit approval; it deletes the server's keys.

## Credentials and records

- The owner types the admin password in step 8. Do not enter, generate or store it.
- `~/netbird/config.yaml` holds secrets. Do not print it, copy it into chat, or commit it.
- Record in `records/` at the repository root: the server type and region, the domain, preflight output, versions, `verify.sh` output, and open issues. No IP addresses of the owner's workstation, no secrets.
