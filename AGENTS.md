# Repository instructions

This is the private working repository for the Self-Hosting 101 series. A public repository with only the files viewers need comes later. Write guides and scripts as if they are already public; keep working notes, agent pointers, and anything in `records/` out of that future copy.

Read [README.md](README.md) for navigation and [CONTRIBUTING.md](CONTRIBUTING.md) before adding or reorganizing content. These rules apply everywhere in the repository; a topic's own `AGENTS.md` adds to them.

## Choose the workflow

- Before operating on a server, read the topic's README, any AGENTS.md files along its path, and its linked skill if present.
- For the Proxmox guide, that is [the topic rules](infrastructure/proxmox-hetzner/AGENTS.md), [the installation guide](infrastructure/proxmox-hetzner/README.md), and [the installation skill](skills/install-proxmox-hetzner/SKILL.md). Its helpers and tests live in `infrastructure/proxmox-hetzner/`.
- Use the shared scripts and verification steps. Do not write a separate installation procedure for agents.
- Do not use planned topics or unfilled templates as deployment instructions.

## Scope and authorization

- Reviewing or editing the repository does not authorize server changes. Establish the real target before connecting.
- An inspection request authorizes read-only inventory. Destructive work requires approval for the target and affected resources under the selected guide's rules.
- Existing approval stays valid unless the target or the destructive scope changes. A prior deployment record does not authorize another deployment.
- Limit work to the requested task. Do not add applications, networks, or services without a separate request.
- After an interruption, inspect the current operation and resource state before retrying. Never rerun a destructive installer automatically.

## Credentials and evidence

- Keep credentials, private keys, populated deployment files, modified installer images, and raw logs out of Git and tool transcripts.
- Use the user's approved SSH public key. Do not export a private key when an approved SSH agent can provide access.
- Do not disable SSH host-key verification globally.
- Store private checkpoints in `records/` at the repository root, even when working from a topic folder. Git ignores that directory; create it if it does not exist.
- Publish sanitized evidence. State what passed, what failed, and what remains unverified. Never claim access is ready without explaining the credential handoff.

## Maintain the series

- Keep guide-specific scripts, tests, images, and teaching materials with that topic. Keep episode order in `episodes/README.md`.
- Update references, command working directories, skill paths, and tests together when files move.
- Preserve recorded test dates and limitations. Record local checks separately from live deployment tests.
- List only existing material as available. Label drafts, planned work, and exports based on older revisions.
- Write concise instructions with expected results and failure conditions. Label the environment for each command: workstation, Rescue, temporary installed QEMU guest, or physical Proxmox host.
