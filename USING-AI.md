# Using an AI agent

Use these guides with Claude Code, Codex, Cursor, or another agent that can read your local copy of the repository. The prompt below tells the agent which instructions to read. It needs no tool-specific integration, but I have not tested it with every agent.

## Starting prompt

Open the repository in your tool and replace `GUIDE_PATH` and `DESCRIBE_THE_OUTCOME`:

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

For the current guide, use `infrastructure/proxmox-hetzner` as `GUIDE_PATH`. A good first task is: "Check whether my server fits this installation guide. Do not install anything."

## Shared instructions

| File | Purpose |
|---|---|
| [Root AGENTS.md](AGENTS.md) | Repository-wide working rules |
| A guide's `AGENTS.md`, when present | Rules specific to that workflow |
| A guide's `README.md` | Procedure for both people and agents |
| A linked `skills/.../SKILL.md`, when present | Agent checklist over the same procedure and helpers |
| `tested-configuration.md`, when present | Recorded results and limits of the tested setup |

Claude Code reads `CLAUDE.md` at the repository root, which imports the root AGENTS.md. Codex reads AGENTS.md directly. If your tool does not load one of these files on its own, tell it to read the file. The [Proxmox installation skill](skills/install-proxmox-hetzner/SKILL.md) needs the repository's scripts even if you copy it into a tool's skills directory. Claude Code finds it through the pointer in `.claude/skills/`, which defers to that file.

## What you approve

The full rules are in [AGENTS.md](AGENTS.md). For you as the owner, they come down to this:

- Asking for an inspection lets the agent run read-only checks. It does not let it change anything.
- Destructive steps need your approval for the exact target. For the Proxmox guide that is the server, both disk serials, the storage layout, and the IPv6 policy. The agent asks once and again only if that scope changes.
- Keep private keys, passwords, populated answer files, and raw logs out of the chat. Use your SSH agent for authentication. Private evidence goes in a `records/` directory at the repository root; Git ignores it, and you create it when you need it.
- After a timeout or a dropped SSH session, the agent must inspect the current state before retrying. A timeout is not permission to restart an installer.
- Do not accept an installation as complete until the guide's final checks passed and the agent has told you how you get the root password.

## Maintaining a guide

For documentation or repository changes, ask the agent to follow [CONTRIBUTING.md](CONTRIBUTING.md), update affected links and examples, and run the local checks. Editing a guide never authorizes changes to a server.
