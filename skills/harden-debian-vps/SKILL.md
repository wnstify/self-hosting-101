---
name: harden-debian-vps
description: Harden a fresh Debian 13 VPS so it accepts SSH keys only - admin user with sudo, no root or password login, ufw, automatic security updates - using the Self-Hosting 101 scripts. Use for an authorized new VPS, such as the self-hosted NetBird or Pangolin server. Does not install applications.
---

# Harden a Debian 13 VPS

Work from a checkout of the self-hosting-101 repository. If this skill was installed into a personal skills folder, locate the checkout first. Read the root `AGENTS.md`, then `security/debian-vps-hardening/README.md`. The guide owns the commands; this skill is the checklist over them. When the two differ, the guide wins.

Supported: Debian 13 on a VPS with IPv4, a key added at server creation, root SSH login available at the start. `tested-configuration.md` lists what is untested; for anything on that list, say so and stop.

## Checkpoints

Record each outcome in `records/` at the repository root (git-ignored; create it).

1. **Establish the target.** Confirm the server address, that the owner created it themselves, and that they authorize these changes. Ask for the user name to create and the sudo mode. Explain the passwordless sudo trade-off in one sentence and let the owner choose. Done when you have `SERVER`, `ADMIN_USER` and `SUDO_MODE`.
2. **First login.** Guide step 1. On a first connection to a new server, the owner accepts the host key; never turn host-key checking off. Done when you have a root prompt with key authentication.
3. **Copy and run the user phase.** Guide steps 2 and 3. Done when `harden.sh user` ends with "Next: keep this root session open". A refusal means read its message and fix the cause; do not work around it.
4. **Second login.** Guide step 4. Ask the owner to open a second session as `ADMIN_USER` and run `sudo whoami`, or do it yourself in a separate connection while the root one stays open. Done when it returns `root`. The owner confirms this; you never set `CONFIRMED_LOGIN` without that confirmation.
5. **Lock.** Guide step 5. Done when `harden.sh lock` prints three `no` lines and "Locked." Keep the root session open.
6. **Verify from the workstation.** Guide step 6. Done when `verify-ssh.sh` prints three `PASS` lines. On any `FAIL`, stop and fix with both sessions open.
7. **Firewall and updates.** Guide step 7, with only the ports the owner's service needs. Use `SSH_ALLOW_FROM` only when the owner confirms a fixed address. Done when ufw is active with the SSH rule first and unattended-upgrades is `enabled`. Mention that Docker-published ports bypass ufw if Docker will run here.
8. **Report.** List what passed, what failed, and what is unverified. Tell the owner both ways back in: the provider console, and the open session until they close it.
