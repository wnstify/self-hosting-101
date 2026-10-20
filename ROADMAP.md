# Roadmap

Topics get a guide when I build and record the setup. The order below is the planned viewing order. Tools and order can still change; the [episode index](episodes/README.md) is the record of what was actually recorded.

## What the series builds

One bare-metal server instead of a fleet of cloud VMs, running trusted open source software. The stack is the one I run myself:

- Proxmox VE on a ZFS mirror as the host.
- AdGuard Home as the DNS server for every guest.
- [NetBird](https://netbird.io), a WireGuard-based private network: SSH to the host and guests, and a route to the private subnet from your own machine. You choose NetBird Cloud (the series default, and what I run) or a [self-hosted NetBird server](networking/netbird-selfhosted/README.md). A self-hosted one runs alone on its own small VPS.
- A self-hosted [Pangolin](https://github.com/fosrl/pangolin) instance on its own small VPS as the public entry point. Pangolin is a tunneled reverse proxy. It terminates TLS and puts access rules, IP allowlists, and [CrowdSec](https://www.crowdsec.net) blocking in front of every published app, including the Proxmox GUI.
- Backups before the second application.

Every app gets one of three tiers before it is installed: admin surfaces on the private network only, personal apps behind Pangolin with authentication, public sites behind Pangolin without it.

## How the guides are meant to be used

You can type every command yourself, or hand a guide to an AI agent with the [starting prompt](USING-AI.md). The guides are written so the agent has nothing to invent: the scripts carry the safety checks and refuse to run when the target, the disk serials, or the boot mode do not match. You keep the password manager, the private key, the provider console, and the approval for anything destructive. Each guide ends with checks the agent reports and a shorter list you confirm yourself in a browser.

## Planned order

| # | Topic | Guide | Video |
|---|---|---|---|
| 1 | Prerequisites: password manager with an SSH agent and an ed25519 key, a domain, a NetBird Cloud account and client (or a self-hosted server, episode 3), a self-hosted Pangolin VPS, and setting up the agent with this repository | Planned, as separate guides under security and networking | Planned, one video with chapters |
| 2 | [Proxmox on bare metal](infrastructure/proxmox-hetzner/README.md) | Available. See the [tested configuration](infrastructure/proxmox-hetzner/tested-configuration.md) | Recording |
| 3 | [Self-hosted NetBird](networking/netbird-selfhosted/README.md): Cloud or self-hosted, a hardened Debian 13 VPS, NetBird's installer pinned and checksummed | Draft | Recording |
| 4 | Single node and guest networking: a Proxmox SDN zone with a private subnet, address plan, host firewall | Planned | Planned |
| 5 | AdGuard Home as the first guest: DNS for all guests, encrypted upstream, start order, internal name resolution | Planned | Planned |
| 6 | NetBird on the host: route to the private subnet, SSH over the private network, public ports closed with the provider console as the way back in | Planned | Planned |
| 7 | Pangolin connection: Newt, Pangolin's tunnel client, in a container, first published app, Proxmox GUI behind Pangolin with access rules and CrowdSec | Planned | Planned |
| 8 | Backups: destination, schedule, and a restore on camera | Planned | Planned |
| 9 onward | Applications, one per episode, each assigned a tier before installation, built on the [Compose recipes](applications/docker-recipes/README.md) | Planned | Planned |

Somewhere in the middle I want one episode where something breaks and gets recovered. A failed boot, a lost Pangolin VPS, or a wrong firewall rule.

## Decisions so far

- Legacy BIOS everywhere, and IPv6 disabled in the kernel. An IPv6-only VPS is unreachable from this host; the series stays IPv4 until a guide validates the alternative.
- NetBird Cloud is the default: no server to maintain and no open ports. Self-hosting is a documented option for anyone who wants to own the control plane. Either way, traffic stays peer to peer.
- A self-hosted NetBird server and the Pangolin server each run alone on their own VPS. They are the way in, so they never share a box with what they protect, and SSH to them stays open on their public address.
- Pangolin is self-hosted because its VPS is the one machine meant to be exposed.
- No third-party post-install scripts on the host. Anything a guide needs lives in this repository. Community container scripts are used only after reading what they do.
- Guardrails go into scripts, not prose. An agent can skip a sentence; it cannot skip a check that exits.

## Later

| Category | Possible guides |
|---|---|
| Infrastructure | VM templates and cloud-init, storage planning |
| Security | Hardware-backed SSH keys, MFA, secrets management |
| Operations | Monitoring, alerts, update procedures, troubleshooting |
| Backups | Retention policy, off-site copies, restore drills |

Status words are defined in [CONTRIBUTING.md](CONTRIBUTING.md#status-conventions).
