# Self-Hosting 101

This repository goes with my YouTube series on secure self-hosting. Each video gets a written guide here, with the scripts and checks used on screen. When something breaks or changes after a video is out, I fix the guide, so the text can differ from the recording. Read a guide's tested configuration before you run it on your own server.

## Start here

- [Start here](START-HERE.md) is the checklist to read before following any guide.
- [About](ABOUT.md) says who makes this series and how it is funded.
- [Episode index](episodes/README.md) connects videos to their guides and materials.
- [Using an AI agent](USING-AI.md) gives a starting prompt and explains what you approve.
- [Roadmap](ROADMAP.md) lists what is in progress and what may come next.

## Browse by topic

| Topic | Covers | Available guides |
|---|---|---|
| [Infrastructure](infrastructure/README.md) | Servers, virtualization, storage, container hosts | [Proxmox on bare metal](infrastructure/proxmox-hetzner/README.md) |
| [Networking](networking/README.md) | DNS, routing, private networks, reverse proxies, TLS | Planned |
| [Security](security/README.md) | SSH, firewalls, access control, MFA, secrets | Planned |
| [Applications](applications/README.md) | Installation and maintenance of individual apps | Planned. [Compose recipes](applications/docker-recipes/README.md) exist without a guide |
| [Backups](backups/README.md) | Backup storage, retention, restore tests, disaster recovery | Planned |
| [Operations](operations/README.md) | Monitoring, alerts, logs, updates, troubleshooting | Planned |

## First guide

[Install Proxmox VE on a bare-metal server](infrastructure/proxmox-hetzner/README.md) covers legacy BIOS, a two-NVMe ZFS mirror, base networking, updates, and verification. It works on any bare-metal server whose provider offers a Debian-based rescue system with KVM; Hetzner is recommended because that is where I tested it. It erases both selected disks. The clean run I recorded was on a Hetzner AX41 on 2026-09-07; the [tested configuration](infrastructure/proxmox-hetzner/tested-configuration.md) lists what passed, what changed since, and what was not tested.

The Proxmox video is still being recorded. It is episode 2; the prerequisites video comes first. Links appear in the episode index at publication.

## How the repository is organized

Each topic directory holds its guide, scripts, tests, and images. Documents, slides, and downloads go in that topic's `materials/` directory, each labeled with the guide revision it follows. There are no materials yet. The Markdown guide is always the maintained version; a PDF or an older video may show an earlier workflow.

Contributors and agents: [CONTRIBUTING.md](CONTRIBUTING.md) has the layout, status conventions, and update process, and [AGENTS.md](AGENTS.md) has the working rules.

If a guide worked for you, a star on this repository helps the next person find it. That is the whole ask.

## License and reporting

Scripts are under the [MIT License](LICENSE). Guides, images, and other written material are under [CC BY 4.0](LICENSE-DOCS); credit Webnestify Education when you reuse them. Report a wrong step or a misbehaving script through the [issue templates](https://github.com/wnstify/self-hosting-101/issues/new/choose). Report a security flaw privately as described in [SECURITY.md](SECURITY.md).
