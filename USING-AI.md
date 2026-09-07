# Using an AI agent

You can give these guides to Claude Code, Codex, Cursor, or another agent that can read your checkout. Use the explicit prompt below so the workflow does not depend on automatic instruction discovery. Tool-specific integrations are not required for this approach, and compatibility has not been tested across every agent.

## Starting prompt

Open a checkout in your tool and replace `GUIDE_PATH` and the task description:

```text
I am using the Self-Hosting 101 repository.
Read the root README.md and AGENTS.md, then GUIDE_PATH/README.md and
any AGENTS.md files along that directory path. Read the linked skill
and tested configuration if the guide has them.

My task is: DESCRIBE_THE_OUTCOME.

Start by reviewing the guide and identifying the information needed.
Before connecting, establish the target and the scope I authorize.
Use read-only inspection to compare the target with the prerequisites.
Explain any mismatch before proposing changes.

Follow the guide's shared scripts and verification steps. Label where
commands run. Apply the documented approval rules before destructive
work, and keep credentials and private logs out of chat and git.
Report what passed, what failed, and what remains unverified.
```

For the current guide, use `infrastructure/proxmox-hetzner` as `GUIDE_PATH`. A first task could be: "Check whether my server fits this installation guide. Do not install anything."

## Shared instructions

| File | Purpose |
|---|---|
| [Root AGENTS.md](AGENTS.md) | Repository-wide working rules |
| A guide's `AGENTS.md`, when present | Rules specific to that workflow |
| A guide's `README.md` | Procedure for both people and agents |
| A linked `skills/.../SKILL.md`, when present | Agent workflow that uses the same procedure and helpers |
| `tested-configuration.md`, when present | Recorded results and limits of the tested setup |

If your tool does not load one of these files automatically, tell it to read the file. The [Proxmox installation skill](skills/install-proxmox-hetzner/SKILL.md) needs the companion repository files even if you copy it into a tool's skills directory.

## Working on a server

An inspection request authorizes read-only checks. Installation needs approval for the actual server, disk serials, storage layout, and IPv6 policy. Existing approval remains valid while that scope stays the same.

Use your SSH agent or another approved local credential method. Do not paste private keys, passwords, populated answer files, or raw installation logs into the conversation. Keep private checkpoints under the git-ignored root `records/` directory.

An agent must inspect the current operation after an interruption before retrying. A timeout is not permission to restart an installer. Require the guide's final checks and a clear credential handoff before accepting an installation as complete.

## Maintaining a guide

For documentation or repository changes, ask the agent to follow [CONTRIBUTING.md](CONTRIBUTING.md), update affected links and examples, and run the relevant local checks. Editing a guide does not authorize changes to a server.
