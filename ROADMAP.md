# Roadmap

Topics get a guide when I build and record the setup. The order below is the planned viewing order. Tools and order can still change; the [episode index](episodes/README.md) is the record of what was actually recorded.

## What the series builds

One bare-metal server instead of a fleet of cloud VMs, running trusted open source software. The stack is the one I run myself:

- Proxmox VE on a ZFS mirror as the host.
- AdGuard Home as the DNS server for every guest.
- Netbird for the private network: SSH to the host and guests, and a route to the private subnet from your own machine. The hosted control plane, with self-hosting as the fallback.
- A self-hosted Pangolin instance on a small VPS as the public entry point: TLS, access rules, IP allowlists, and CrowdSec in front of every published app, including the Proxmox GUI.
- Backups before the second application.

Every app gets one of three tiers before it is installed: admin surfaces on the private network only, personal apps behind Pangolin with authentication, public sites behind Pangolin without it.

## How the guides are meant to be used

You can type every command yourself, or hand a guide to an AI agent with the [starting prompt](USING-AI.md). The guides are written so the agent has nothing to invent: the scripts carry the safety checks and refuse to run when the target, the disk serials, or the boot mode do not match. You keep the password manager, the private key, the provider console, and the approval for anything destructive. Each guide ends with checks the agent reports and a shorter list you confirm yourself in a browser.

## Planned order

| # | Topic | Guide | Video |
|---|---|---|---|
| 1 | Prerequisites: password manager with an SSH agent and an ed25519 key, a domain, a Netbird account and client, a self-hosted Pangolin VPS, and setting up the agent with this repository | Planned, as separate guides under security and networking | Planned, one video with chapters |
| 2 | [Proxmox on bare metal](infrastructure/proxmox-hetzner/README.md) | Available, see [tested configuration](infrastructure/proxmox-hetzner/tested-configuration.md) | Recording |
| 3 | Single node and guest networking: SDN zone with a private subnet, address plan, host firewall | Planned | Planned |
| 4 | AdGuard Home as the first guest: DNS for all guests, encrypted upstream, start order, internal name resolution | Planned | Planned |
| 5 | Netbird on the host: route to the private subnet, SSH over the private network, public ports closed with the provider console as the way back in | Planned | Planned |
| 6 | Pangolin connection: Newt in a container, first published app, Proxmox GUI behind Pangolin with access rules and CrowdSec | Planned | Planned |
| 7 | Backups: destination, schedule, and a restore on camera | Planned | Planned |
| 8 onward | Applications, one per episode, each assigned a tier before installation, built on the [Compose recipes](applications/docker-recipes/README.md) | Planned | Planned |

Somewhere in the middle, one episode where something breaks and gets recovered. A failed boot, a lost Pangolin VPS, or a wrong firewall rule.

## Decisions so far

- Legacy BIOS everywhere, and IPv6 disabled in the kernel. An IPv6-only VPS is unreachable from this host; the series stays IPv4 until a guide validates the alternative.
- Netbird's hosted control plane rather than a self-hosted one. Traffic stays peer to peer; the migration to self-hosted is the safety net if the service goes away.
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
