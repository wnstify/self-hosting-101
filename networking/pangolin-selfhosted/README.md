# Self-host a Pangolin server

Run your own [Pangolin](https://github.com/fosrl/pangolin) on a small dedicated VPS: a tunneled reverse proxy with a login in front of your apps, a Let's Encrypt certificate, and CrowdSec blocking attackers before they reach anything. Your home network opens no ports. People and AI agents follow the same scripts and checks.

[Networking](../README.md) · [Episode index](../../episodes/README.md) · [Teaching materials](materials/README.md)

| Detail | Value |
|---|---|
| Status | Available. See the [tested configuration](tested-configuration.md) |
| Video | Recording (episode 2) |
| Last live test | 2026-10-21, Debian 13: the scripts on a fresh server, after the same steps by hand on 2026-10-20 and 2026-10-21. See [tested configuration](tested-configuration.md) |
| Materials | None yet |

## Hosted or self-hosted?

Pangolin Cloud and a self-hosted server publish your apps the same way. Pick one:

- **Pangolin Cloud:** no server to maintain. Create an account at [pangolin.net](https://pangolin.net) and skip this guide.
- **Self-hosted** (this guide, and what I run): you own the server that terminates TLS and sees your traffic. In exchange you keep one small server patched and backed up, and it has four Pangolin ports and SSH open to the internet.

## What this guide does

You end up with:

- a dedicated VPS running Pangolin and nothing else, hardened with the [Debian VPS hardening guide](../../security/debian-vps-hardening/README.md);
- Pangolin Community Edition, Gerbil (WireGuard) and Traefik in `/opt/pangolin`, from Pangolin's official installer pinned to the tested release and checked against its SHA-256;
- HTTPS on your own name, such as `pangolin.your-domain.com`, with a Let's Encrypt certificate, and a wildcard under it for the apps you publish later;
- your admin account and first organization;
- CrowdSec with its Traefik bouncer, with three of its defaults changed, and a ban test that proves it blocks.

Out of scope: connecting sites and publishing apps (episode 7), the Enterprise Edition, PostgreSQL, SMTP, IPv6, high availability, and a CrowdSec bouncer for SSH. Pangolin's own documentation covers them; links are at the end.

**Give Pangolin its own server.** It is the public way in to everything you publish. If it shared a box with your apps and that box broke, you would lose the tool you need to reach them. For the same reason, **keep SSH to this server open on its public address; never make Pangolin the only way into the Pangolin server itself.** Limit port 22 to your own fixed address if you have one.

**These ports are open to the internet:** 80/tcp (redirects to HTTPS and answers Let's Encrypt), 443/tcp (the dashboard and every app you publish), 51820/udp (WireGuard tunnels from your sites), 21820/udp (WireGuard tunnels from Pangolin's clients), and 22/tcp for SSH.

The docs ask for at least 1 vCPU, 2 GB RAM and 8 GB of disk, and recommend 2 vCPUs and 20 GB. CrowdSec needs the 2 GB. Tested on Hetzner Cloud with Debian 13, IPv4 only. Other providers need their own validation.

Where commands run: **browser** is your provider's and your DNS provider's web panel, **workstation** is your own computer, **server** is the VPS.

## 1. Create the server (browser)

In your provider's console. Names and values are the tested ones; change them to yours.

1. **Project:** a new project for this server, such as `pangolin`.
2. **SSH key:** add your public key and set it as the project default. Many providers, Hetzner included, cannot add a key to an existing server from the web console.
3. **Firewall:** a cloud firewall named `pangolin` with these inbound rules, IPv4 sources only, no outbound rules:

   | Protocol | Port | Purpose |
   |---|---|---|
   | TCP | 22 | SSH. Limit the source to your fixed IP if you have one |
   | ICMP | | ping |
   | TCP | 80 | redirect to HTTPS, Let's Encrypt |
   | TCP | 443 | dashboard and published apps |
   | UDP | 51820 | WireGuard from sites |
   | UDP | 21820 | WireGuard from clients |

4. **Server:** a shared-CPU type with at least 1 vCPU and 2 GB RAM, image Debian 13, public IPv4 on, IPv6 off, your SSH key ticked, the `pangolin` firewall ticked. Backups are worth turning on. Leave cloud-init empty.

Expected: the server is running and shows its public IPv4 address. Write it down as `SERVER_IP`.

## 2. Point your domain at it (browser)

At your DNS provider, add two A records:

| Type | Name | Value |
|---|---|---|
| A | `pangolin` | `SERVER_IP` |
| A | `*.pangolin` | `SERVER_IP` |

The first is the dashboard. The wildcard is for the apps you publish later, such as `photos.pangolin.your-domain.com`. On Cloudflare, set both to **DNS only** (grey cloud). Cloudflare's proxy would end TLS before Pangolin and cannot carry the WireGuard ports.

Do this before the install. Let's Encrypt checks the name during installation. On the workstation:

```bash
dig +short pangolin.your-domain.com
dig +short anything.pangolin.your-domain.com
```

Expected: both return exactly `SERVER_IP`.

## 3. Harden the server

Follow the [Debian VPS hardening guide](../../security/debian-vps-hardening/README.md), steps 1 to 7. For step 7, open Pangolin's ports in ufw:

```bash
ALLOW_PORTS="80/tcp 443/tcp 51820/udp 21820/udp" ./harden.sh firewall
```

Expected: `verify-ssh.sh` passed, and ufw allows 22/tcp, 80/tcp, 443/tcp, 51820/udp and 21820/udp. ufw does not filter the ports Docker publishes, so the cloud firewall from step 1 is the filter that counts for Pangolin's ports.

## 4. Copy the scripts (workstation)

From the repository root, replacing `alice` with your admin user:

```bash
scp -r networking/pangolin-selfhosted shared/docker alice@pangolin.your-domain.com:~/
```

## 5. Run the preflight (server)

```bash
ssh alice@pangolin.your-domain.com
cd ~/pangolin-selfhosted
PANGOLIN_DOMAIN=pangolin.your-domain.com ./preflight.sh
```

It changes nothing. It checks Debian 13 on x86_64, about 2 GB of memory, free disk, that you are not root, that the name and the wildcard resolve to this server and only this server, that 80, 443, 51820 and 21820 are free, and ufw's rules. Docker may show as missing at this point. Expected: "Preflight passed."

## 6. Install Docker (server)

```bash
sudo DOCKER_USER=alice ~/docker/install-docker.sh
exit
```

It adds Docker's own apt repository for Debian 13 and installs Docker Engine, the Compose plugin and jq. Debian's own `docker.io` package is older, so the guide uses Docker's. `DOCKER_USER` joins the docker group so Docker runs without sudo; Pangolin's installer also refuses to run for a user outside that group. **Anyone in the docker group can take over the server, so add only yourself.** The group applies after a fresh login, hence the `exit`. Expected: the script prints the Docker, Compose and jq versions.

## 7. Install Pangolin (server)

Log in again and run:

```bash
ssh alice@pangolin.your-domain.com
cd ~/pangolin-selfhosted
PANGOLIN_DOMAIN=pangolin.your-domain.com \
PANGOLIN_LETSENCRYPT_EMAIL=you@your-domain.com \
./install-pangolin.sh
```

Use an email address on a real domain. Let's Encrypt refuses placeholders such as `example.com`, and then no certificate is issued.

The script runs the preflight again and refuses an existing installation in `/opt/pangolin`. It downloads Pangolin's installer for the tested release into `~/pangolin-installer` and runs it only if its SHA-256 matches the value in [lib.sh](lib.sh). Nothing is piped into a shell. It asks for sudo once, then answers the installer's questions one at a time, and stops the installer if a question it does not expect comes up:

| Question | Answer |
|---|---|
| Installation directory | `/opt/pangolin` (the default), created and owned by you |
| Enterprise Edition | No: Community Edition |
| PostgreSQL | No: SQLite |
| Base domain, dashboard domain | `PANGOLIN_DOMAIN` for both |
| Let's Encrypt email | `PANGOLIN_LETSENCRYPT_EMAIL` |
| Gerbil for tunneled connections | Yes |
| Email (SMTP) | No |
| IPv6 | No |
| MaxMind GeoLite2 databases | Yes, for country and ASN blocking rules |
| Install and start the containers | Yes, with Docker |

The Enterprise Edition is free for personal use and small businesses, but this guide has only tested the Community Edition.

Expected: the script lists the three containers `pangolin`, `gerbil` and `traefik` as running and prints the next steps.

## 8. Create the admin account (browser)

The installer generated a one-time setup token. Read it yourself on the server:

```bash
docker logs pangolin 2>&1 | grep -A 3 'SETUP TOKEN'
```

Open `https://pangolin.your-domain.com/auth/initial-setup`, paste the token, and enter your email and a strong password. Then sign in and create your first organization.

**Only you handle the token and the password.** An agent gives you the command above; it never reads, types or stores them for you. Store the password in your password manager. The token stops working once it has been used.

## 9. Add CrowdSec (server)

CrowdSec reads Traefik's access log, spots attacks such as scans and brute force, and bans the addresses behind them. It also pulls a shared blocklist, so an address that attacked someone else can be blocked here first. Its bouncer in Traefik does the blocking.

Two caveats before you add it. The installer calls this a minimal setup and asks whether you are willing to manage CrowdSec; you maintain it from then on. And **it fails closed: if the crowdsec container stops, the apps behind Pangolin go offline with it.**

```bash
cd ~/pangolin-selfhosted
./install-crowdsec.sh
```

The installer skips CrowdSec on a first install, so this is its second run, with `--crowdsec`. It refuses to start while ports 80 and 443 are in use, so the script runs `docker compose down` in `/opt/pangolin` first; the installer starts the stack again. It answers: MaxMind update no, install CrowdSec yes, willing to manage it yes, detected values correct yes.

Then it changes three defaults, checking each file before and after:

| File in `/opt/pangolin/config` | Default | Why it changes |
|---|---|---|
| `crowdsec/profiles.yaml` | web attacks get `type: captcha` | No captcha service is configured, so nothing would be shown. They get `type: ban` |
| `traefik/traefik_config.yml` | the access log skips requests faster than `minDuration: "100ms"` | Fast scanners would never reach CrowdSec. The line goes |
| `traefik/dynamic_config.yml` | `forwardedHeadersTrustedIPs: ["0.0.0.0/0"]` | Any client could fake its address in a header and dodge a ban. Nothing sits in front of Traefik here, so the setting goes |

It refuses instead of guessing when a file does not look like the tested release's, for example when you already put your own proxy addresses under `forwardedHeadersTrustedIPs`. Then it restarts Traefik and CrowdSec and waits until CrowdSec reports healthy.

Expected: "CrowdSec is on, with the three defaults changed." and four running containers.

## Verify the result

On the server:

```bash
cd ~/pangolin-selfhosted
PANGOLIN_DOMAIN=pangolin.your-domain.com ./verify.sh
```

It checks the containers and CrowdSec's health, the four listening ports, HTTPS with a certificate a normal client trusts, the Let's Encrypt issuer, the redirect from port 80, that the Traefik bouncer is registered, and that the three changed defaults are still in place. Expected: "All Pangolin checks passed." Right after the install the certificate can take a minute; rerun if only the HTTPS checks fail.

Then prove CrowdSec blocks. On the **workstation**, from the repository root:

```bash
networking/pangolin-selfhosted/ban-test.sh alice@pangolin.your-domain.com pangolin.your-domain.com
```

It bans the public address the server sees for you for one minute, checks that your own site answers 403, lifts the ban, and checks that it answers again. It must run on the workstation: a request the server makes to itself never comes from your address, so a ban test on the server shows nothing. The bouncer caches answers for about 15 seconds, so the test waits in between. Expected: "Ban test passed."

Also check, yourself:

- the padlock in your browser on `https://pangolin.your-domain.com`, and that you can sign in;
- after `sudo reboot`, `verify.sh` passes again without any manual start.

## Recovery

- **The certificate is never issued:** check that both A records point only to this server (`dig`), that Cloudflare's proxy is off, that 80/tcp and 443/tcp are open in the cloud firewall, and the Traefik log: `docker logs traefik`.
- **The installer stopped part-way:** the script prints the last lines of its log and leaves `~/pangolin-installer/install.log`. Read it before anything else. Never rerun the installer over a half-made `/opt/pangolin` without checking what is there.
- **The CrowdSec pass stopped part-way:** the stack may still be down. Read `~/pangolin-installer/crowdsec.log`, then `cd /opt/pangolin && docker compose up -d`. Before changing anything, the installer saved the previous `docker-compose.yml` as `docker-compose.yml.backup` and the `config` directory as `config.tar.gz`, both in `/opt/pangolin`.
- **Every app and the dashboard answer 403 or nothing:** check `docker ps` for the crowdsec container. CrowdSec fails closed. `cd /opt/pangolin && docker compose up -d crowdsec`, then `docker logs crowdsec`.
- **You banned yourself for longer than the test:** from the provider's web console or another address, `docker exec crowdsec cscli decisions list`, then `docker exec crowdsec cscli decisions delete --ip ADDRESS`.
- **The bouncer key is a placeholder:** the installer could not register the bouncer. Run `docker exec crowdsec cscli bouncers add traefik-bouncer`, put the key into `crowdsecLapiKey` in `dynamic_config.yml` yourself, and restart Traefik. Do not paste the key into a chat.
- **The setup token was lost:** read it again with the command in step 8. If the log no longer shows it, see Pangolin's documentation before you change anything.
- **Locked out of SSH:** the hardening guide's recovery section; the provider's web console still works.

## Maintenance and backups

- **Back up** `/opt/pangolin`. Its `config` directory holds `config.yml` with the server's secret, the SQLite database, the certificates in `config/letsencrypt`, and the CrowdSec configuration and data. Provider backups of the whole server cover all of it. Keep copies private; `config.yml`, `dynamic_config.yml` and the installer's `config.tar.gz` hold secrets.
- **Update Pangolin:** read the release notes first, then follow Pangolin's update guide: set the new image tags in `/opt/pangolin/docker-compose.yml`, then `docker compose pull` and `docker compose up -d`, then run `verify.sh`. CrowdSec's image is `latest`; pin it if you want updates only when you choose.
- **Log rotation:** the installer set up rotation for Traefik's access log in `/etc/logrotate.d/pangolin-traefik`: daily, seven compressed copies.
- **Debian security fixes** install themselves daily. Other updates and kernel reboots are yours, as in the hardening guide.

## Next steps

Connect your first site and publish an app behind Pangolin's login. That is episode 7 in this series. Until then, Pangolin's documentation covers it:

- [Pangolin documentation](https://docs.pangolin.net/)
- [CrowdSec community guide](https://docs.pangolin.net/self-host/community-guides/crowdsec), including a firewall bouncer for SSH on the host

## Agent instructions

Read the [root AGENTS.md](../../AGENTS.md), the [topic rules](AGENTS.md), and the [installation skill](../../skills/install-pangolin-selfhosted/SKILL.md). The owner does steps 1, 2 and 8 in the browser. The agent does the rest with the same scripts.

## References

- [Pangolin: quick install](https://docs.pangolin.net/self-host/quick-install)
- [Pangolin release 1.24.0](https://github.com/fosrl/pangolin/releases/tag/1.24.0)
- [Pangolin installer source](https://github.com/fosrl/pangolin/tree/1.24.0/install)
- [CrowdSec documentation](https://docs.crowdsec.net/)
- [Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)
- [Docker: packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
