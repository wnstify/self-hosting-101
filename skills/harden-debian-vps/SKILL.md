---
name: harden-debian-vps
description: Harden a fresh Debian 13 VPS so it accepts SSH keys only - admin user with sudo, no root or password login, ufw, automatic security updates - using the Self-Hosting 101 scripts. Use for an authorized new VPS, such as the self-hosted NetBird or Pangolin server. Does not install applications.
---

# Harden a Debian 13 VPS

Work from a checkout of the self-hosting-101 repository. If this skill was installed into a personal skills folder, locate the checkout first. Read the root `AGENTS.md`, then `security/debian-vps-hardening/README.md`. The guide owns the commands; this skill is the checklist over them. When the two differ, the guide wins.

Supported: Debian 13 on a VPS with IPv4, a key added at server creation, root SSH login available at the start. `tested-configuration.md` lists what is untested; for anything on that list, say so and stop.

## Ask everything first

Before connecting, ask the owner all of these in one message and wait for the answers. Skip any already answered in the conversation, for example when the NetBird skill called this one. Do not stop for input again afterwards.

1. **Server address**, and that they created it with their SSH key.
2. **Admin user name** to create.
3. **Sudo mode:** passwordless or with a password, with the one-sentence trade-off from the guide.
4. **SSH source:** anyone, or only a fixed IPv4 address.
5. **Ports** the server's service needs, if any.
6. **Host key:** may you accept the new server's key on first connection, and remove only stale entries for this address or name after a rebuild?
7. **Second login:** may you test the admin login yourself in a separate connection and treat a `root` answer from `sudo whoami` as the confirmation for the lock phase?
8. **Authorization** to make these changes on this exact server.

## Checkpoints

Record each outcome in `records/` at the repository root (git-ignored; create it).

1. **Establish the target.** From the answers above. Done when you have `SERVER`, `ADMIN_USER`, `SUDO_MODE`, the SSH source, the ports, and the authorization.
2. **First login.** Guide step 1. Accept the new host key only as the owner agreed in question 6, and remove only this address's and name's stale entries with `ssh-keygen -R`; never turn host-key checking off. Done when you have a root prompt with key authentication.
3. **Copy and run the user phase.** Guide steps 2 and 3. Done when `harden.sh user` ends with "Next: keep this root session open". A refusal means read its message and fix the cause; do not work around it.
4. **Second login.** Guide step 4. With the owner's yes to question 7, open a separate connection as `ADMIN_USER` while the root one stays open and run `sudo whoami`. Otherwise ask the owner to do it. Done when it returns `root`. Set `CONFIRMED_LOGIN` only on that result.
5. **Lock.** Guide step 5. Done when `harden.sh lock` prints three `no` lines and "Locked." Keep the root session open.
6. **Verify from the workstation.** Guide step 6. Done when `verify-ssh.sh` prints three `PASS` lines. On any `FAIL`, stop and fix with both sessions open.
7. **Firewall and updates.** Guide step 7, with only the ports the owner's service needs. Use `SSH_ALLOW_FROM` only when the owner confirms a fixed address. Done when ufw is active with the SSH rule first and unattended-upgrades is `enabled`. Mention that Docker-published ports bypass ufw if Docker will run here.
8. **Report.** List what passed, what failed, and what is unverified. Tell the owner both ways back in: the provider console, and the open session until they close it.
