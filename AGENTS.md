# Repository instructions

This is the companion repository for an ongoing self-hosting video series. Read [README.md](README.md) for navigation and [CONTRIBUTING.md](CONTRIBUTING.md) before adding or reorganizing content.

## Choose the workflow

- Read the selected topic's README, any AGENTS.md files along its path, and its linked skill before operating on a server.
- For Proxmox on Hetzner, read [the topic rules](infrastructure/proxmox-hetzner/AGENTS.md), [the installation guide](infrastructure/proxmox-hetzner/README.md), and [the installation skill](skills/install-proxmox-hetzner/SKILL.md). Its helpers and tests live in `infrastructure/proxmox-hetzner/`.
- Use the shared scripts and verification steps. Do not create a separate installation procedure for agents.
- Planned topics and example templates are not tested deployment workflows.

## Scope and authorization

- Repository review or editing does not authorize server changes. Establish the actual target before connecting.
- An inspection request authorizes read-only inventory. Destructive work requires approval for the target and affected resources under the selected guide's rules.
- Existing approval remains valid unless the target or destructive scope changes. Prior deployment records are evidence, not authorization for another deployment.
- Limit work to the user's requested task. Do not add applications, networks, or services without a separate request.
- After an interruption, inspect the current operation and resource state before retrying. Never automatically rerun a destructive installer.

## Credentials and evidence

- Keep credentials, private keys, populated deployment files, modified installer images, and raw logs out of Git and tool transcripts.
- Use the user's approved SSH public key. Do not export a private key when an approved SSH agent can provide access.
- Do not disable SSH host-key verification globally.
- Store private checkpoints under the repository root's git-ignored `records/` directory, even when working from a topic folder.
- Publish sanitized evidence. State what passed, what failed, and what remains unverified. Never claim access is ready without explaining the credential handoff.

## Maintain the series

- Keep guide-specific scripts, tests, images, and teaching materials with that topic. Keep episode order in `episodes/README.md`.
- Update references, command working directories, skill paths, and tests together when files move.
- Preserve recorded test dates and limitations. A local check or documentation edit is not a new live deployment test.
- List only available material as available. Label drafts, planned work, and exports based on older revisions.
- Write concise instructions with expected results and failure conditions. Label the environment for each command, such as workstation, Rescue, temporary installed QEMU guest, or physical Proxmox host.
