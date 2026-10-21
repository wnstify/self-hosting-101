# Self-host a NetBird server

Run your own NetBird management server, signal, relay and dashboard on a small dedicated VPS, with a Let's Encrypt certificate and nothing open except the ports NetBird needs and SSH. People and AI agents follow the same scripts and checks.

[Networking](../README.md) · [Episode index](../../episodes/README.md) · [Teaching materials](materials/README.md)

| Detail | Value |
|---|---|
| Status | Available. See the [tested configuration](tested-configuration.md) |
| Video | Recording (episode 3) |
| Last live test | 2026-10-20, Hetzner CPX12, Debian 13: the scripts on a fresh server and the same steps by hand. See [tested configuration](tested-configuration.md) |
| Materials | None yet |

## Hosted or self-hosted?

NetBird Cloud and a self-hosted server give you the same private network. Pick one:

- **NetBird Cloud** (the series default, and what I run): no server to maintain and no open ports anywhere. Create an account at [netbird.io](https://netbird.io) and skip this guide.
- **Self-hosted** (this guide): you own the control plane. In exchange you keep one small server patched and backed up, and that server has three NetBird ports and SSH open to the internet.

## What this guide does

You end up with:

- a dedicated VPS running NetBird and nothing else, hardened with the [Debian VPS hardening guide](../../security/debian-vps-hardening/README.md);
- NetBird's combined server (management, signal, relay, STUN), the dashboard and Traefik, from NetBird's official installer pinned to the tested release;
- HTTPS on your own name, such as `netbird.your-domain.com`, with a Let's Encrypt certificate;
- the built-in login (no separate identity provider) and your first admin account.

Out of scope: the NetBird Proxy, CrowdSec, an external identity provider, IPv6, high availability, and joining devices. NetBird's own guides cover joining devices; links are at the end.

**Give NetBird its own server.** It is the way into everything else. If it shared a box with your other services and that box broke, you would lose the tool you need to fix it. For the same reason, **keep SSH to this server open on its public address; never make NetBird the only way into the NetBird server itself.** Limit port 22 to your own fixed address if you have one.

**These ports are open to the internet:** 80/tcp (redirects to HTTPS), 443/tcp (dashboard, device connections, relay, and the Let's Encrypt check), 3478/udp (STUN, so devices can find a direct path), and 22/tcp for SSH. NetBird does not need WireGuard's 51820/udp here; only the optional NetBird Proxy uses it.

Tested on a Hetzner Cloud CPX12 (1 vCPU, 2 GB RAM) in Falkenstein with Debian 13, IPv4 only. Other providers need their own validation.

Where commands run: **browser** is your provider's and your DNS provider's web panel, **workstation** is your own computer, **server** is the VPS.

## 1. Create the server (browser)

In your provider's console. Names and values are the tested ones; change them to yours.

1. **Project:** a new project for this server, such as `netbird-selfhost`.
2. **SSH key:** add your public key and set it as the project default. Many providers, Hetzner included, cannot add a key to an existing server from the web console.
3. **Firewall:** a cloud firewall named `netbird` with these inbound rules, IPv4 sources only, no outbound rules:

   | Protocol | Port | Purpose |
   |---|---|---|
   | TCP | 22 | SSH. Limit the source to your fixed IP if you have one |
   | ICMP | | ping |
   | TCP | 80 | redirect to HTTPS |
   | TCP | 443 | dashboard, devices, relay, Let's Encrypt |
   | UDP | 3478 | STUN |

4. **Server:** a shared-CPU type with at least 1 vCPU and 2 GB RAM (tested: CPX12), image Debian 13, public IPv4 on, IPv6 off, your SSH key ticked, the `netbird` firewall ticked. Backups are worth turning on; a placement group of type Spread is optional and only matters once you run several servers. Leave cloud-init empty.

Expected: the server is running and shows its public IPv4 address. Write it down as `SERVER_IP`.

## 2. Point your domain at it (browser)

At your DNS provider, add an A record:

| Type | Name | Value |
|---|---|---|
| A | `netbird` | `SERVER_IP` |

On Cloudflare, set the proxy status to **DNS only** (grey cloud). Cloudflare's proxy passes web traffic only, so 3478/udp and the certificate check would fail through it. A wildcard CNAME (`*.netbird`) is only needed for the NetBird Proxy, which this guide does not enable.

Do this before the install. Let's Encrypt checks the name during installation. On the workstation:

```bash
dig +short netbird.your-domain.com
```

Expected: exactly `SERVER_IP`.

## 3. Harden the server

Follow the [Debian VPS hardening guide](../../security/debian-vps-hardening/README.md), steps 1 to 7. For step 7, open NetBird's ports in ufw:

```bash
ALLOW_PORTS="80/tcp 443/tcp 3478/udp" ./harden.sh firewall
```

Expected: `verify-ssh.sh` passed, and ufw allows 22/tcp, 80/tcp, 443/tcp and 3478/udp. ufw does not filter the ports Docker publishes, so the cloud firewall from step 1 is the filter that counts for NetBird's ports.

## 4. Copy this guide's scripts (workstation)

From the repository root, replacing `alice` with your admin user. The Docker installer is shared with the Pangolin guide and lives in `shared/docker`:

```bash
scp -r networking/netbird-selfhosted shared/docker alice@netbird.your-domain.com:~/
```

## 5. Run the preflight (server)

```bash
ssh alice@netbird.your-domain.com
cd ~/netbird-selfhosted
NETBIRD_DOMAIN=netbird.your-domain.com ./preflight.sh
```

It changes nothing. It checks Debian 13 on x86_64, about 2 GB of memory, free disk, that you are not root, that the name resolves to this server and only this server, that 80, 443 and 3478 are free, and ufw's rules. Docker may show as missing at this point. Expected: "Preflight passed."

## 6. Install Docker (server)

```bash
sudo DOCKER_USER=alice ~/docker/install-docker.sh
exit
```

It adds Docker's own apt repository for Debian 13 and installs Docker Engine, the Compose plugin and jq; NetBird's installer needs all three. Debian's own `docker.io` package is older, so the guide uses Docker's. `DOCKER_USER` joins the docker group so Docker runs without sudo. **Anyone in the docker group can take over the server, so add only yourself.** The group applies after a fresh login, hence the `exit`. Expected: the script prints the Docker, Compose and jq versions.

## 7. Install NetBird (server)

Log in again and run:

```bash
ssh alice@netbird.your-domain.com
cd ~/netbird-selfhosted
NETBIRD_DOMAIN=netbird.your-domain.com \
NETBIRD_LETSENCRYPT_EMAIL=you@your-domain.com \
./install-netbird.sh
```

Use an email address on a real domain. Let's Encrypt refuses placeholders such as `example.com`, and then no certificate is issued.

The script runs the preflight again, refuses an existing installation in `~/netbird`, downloads NetBird's `getting-started.sh` for the tested release, and runs it only if its SHA-256 matches the value in [lib.sh](lib.sh). It answers the installer's questions for you: built-in Traefik, NetBird Proxy off, CrowdSec off, and the tested image versions. You can read `~/netbird/getting-started.sh` before or after; nothing is piped into a shell.

Expected: the installer ends with "NETBIRD SETUP COMPLETE" and lists the open ports 443/tcp, 80/tcp and 3478/udp. The run took about 15 seconds on the tested server, image downloads included.

## 8. Create the admin account (browser)

Open `https://netbird.your-domain.com`. On a fresh install it shows **Welcome to NetBird**: enter a name, an email and a strong password, then **Create Admin Account**. It then asks you to sign in with the same details and opens the onboarding screen. Since January 2026 this login is built into NetBird, so you need no separate identity provider.

**Only you type this password.** An agent never enters it for you. Store it in your password manager.

## Verify the result

On the server:

```bash
cd ~/netbird-selfhosted
NETBIRD_DOMAIN=netbird.your-domain.com ./verify.sh
```

It checks the three containers, the listening ports, HTTPS with a certificate a normal client trusts, the login service, the Let's Encrypt issuer, and the redirect from port 80. Expected: "All NetBird checks passed." Right after the install the certificate can take a minute; rerun if only the HTTPS checks fail.

Also check, yourself:

- the padlock in your browser on `https://netbird.your-domain.com`;
- after `sudo reboot`, `verify.sh` passes again without any manual start.

## Recovery

- **The certificate is never issued:** check that the A record points only to this server (`dig`), that Cloudflare's proxy is off, that 80/tcp and 443/tcp are open in the cloud firewall, and the Traefik log: `docker logs netbird-traefik`.
- **A container keeps restarting:** `cd ~/netbird && docker compose ps` and `docker compose logs netbird-server`.
- **Locked out of SSH:** the hardening guide's recovery section; the provider's web console still works.
- **Start over on the same server:** the installer prints the cleanup command when it finds an old configuration. It deletes the configuration and with it the server's keys and secrets, so every device would have to join again. Restore from backup instead if devices already use it.

## Maintenance and backups

- **Back up** `~/netbird` (it holds `config.yaml` with the server's secrets, `docker-compose.yml` and `dashboard.env`) and the Docker volumes `netbird_netbird_data` and `netbird_netbird_traefik_letsencrypt`. Provider backups of the whole server cover all of it. Keep copies private; `config.yaml` is a secret.
- **Update NetBird:** read the release notes first. The images are pinned to tested versions, so set the new tags in `~/netbird/docker-compose.yml`, then:

  ```bash
  cd ~/netbird
  docker compose pull
  docker compose up -d
  ```

  Then run `verify.sh`.
- **Debian security fixes** install themselves daily. Other updates and kernel reboots are yours, as in the hardening guide.

## Next steps

Set up users, groups, policies and your first devices. NetBird's own guides walk through that, many of them by Brandon Hopkins from NetBird:

- [Get Started with NetBird: Access your Entire Network!](https://www.youtube.com/watch?v=C5tu3Ce0r8Q)
- [Local User MFA in NetBird Self-Hosted](https://www.youtube.com/watch?v=PT_tqZtp7DM)
- [Self-Host NetBird + Authentik](https://www.youtube.com/watch?v=ri3JvbylwS0), if you want an external identity provider
- [NetBird documentation](https://docs.netbird.io/)

On a self-hosted server, point each client at your own address first, in the app's settings or with `netbird up --management-url https://netbird.your-domain.com`.

## Agent instructions

Read the [root AGENTS.md](../../AGENTS.md), the [topic rules](AGENTS.md), and the [installation skill](../../skills/install-netbird-selfhosted/SKILL.md). The owner does steps 1, 2 and 8 in the browser. The agent does the rest with the same scripts.

## References

- [NetBird: self-hosting quickstart](https://docs.netbird.io/selfhosted/selfhosted-quickstart)
- [NetBird release v0.81.3](https://github.com/netbirdio/netbird/releases/tag/v0.81.3)
- [Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)
- [Docker: Linux post-install](https://docs.docker.com/engine/install/linux-postinstall/), on the docker group
- [Docker: packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
