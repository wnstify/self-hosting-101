# Self-Hosting 101

The companion repository for an ongoing YouTube series about secure self-hosting. Follow the videos, work through the written guides, or use an AI agent to help with a task.

New topics and applications will appear as the series grows. Written guides can receive fixes and updates after a video is published. Check each guide's tested configuration before using it on your server.

## Start here

- [Getting started](START-HERE.md) explains how to follow the guides.
- [Episode index](episodes/README.md) connects videos to their guides and teaching materials.
- [Using an AI agent](USING-AI.md) provides a starting prompt and explains the shared instructions.
- [Roadmap](ROADMAP.md) tracks possible future topics and work in progress.

## Browse by topic

| Topic | Covers | Available guides |
|---|---|---|
| [Infrastructure](infrastructure/README.md) | Servers, virtualization, storage, container hosts | [Proxmox on Hetzner](infrastructure/proxmox-hetzner/README.md) |
| [Networking](networking/README.md) | DNS, routing, private networks, reverse proxies, TLS | Planned |
| [Security](security/README.md) | SSH, firewalls, access control, MFA, secrets | Planned |
| [Applications](applications/README.md) | Installation and maintenance of individual apps | Planned |
| [Backups](backups/README.md) | Backup storage, retention, restore tests, disaster recovery | Planned |
| [Operations](operations/README.md) | Monitoring, alerts, logs, updates, troubleshooting | Planned |

## First guide

[Install Proxmox VE on Hetzner](infrastructure/proxmox-hetzner/README.md) covers installation through Linux Rescue, a two-NVMe ZFS mirror, base networking, administrative access, and validation. It requires legacy BIOS and erases both approved disks. Read its [tested configuration](infrastructure/proxmox-hetzner/tested-configuration.md) for evidence and limitations.

The first video is being recorded. Its link will appear in the episode index when published.

## Guides and teaching materials

Each topic keeps its instructions, scripts, tests, and images together. Companion documents, slides, and downloadable exports belong in that topic's `materials/` directory and are linked from its guide. Materials are added when available.

Markdown guides contain the maintained instructions. PDFs and slide decks identify the guide revision they accompany. An older video or download may show an earlier workflow.

See [contributing and repository layout](CONTRIBUTING.md) for naming, templates, and the update process. Agents should read [AGENTS.md](AGENTS.md) before working in the repository.
