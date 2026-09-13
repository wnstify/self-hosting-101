# Docker Compose recipes

Compose files and environment examples for 22 self-hosted applications. Each folder is a self-contained Docker Compose deployment: one `compose.yaml` and one `.env.example` whose comments are the instructions. The planned application guides will build on these files.

[Applications](../README.md) · [Episode index](../../episodes/README.md)

| Detail | Value |
|---|---|
| Status | Available |
| Guide | None yet; the comments in each `.env.example` are the instructions |
| Last local check | 2026-09-09 on rootless Docker, both flavors of all 22 applications, see [the checklist](verification/CHECKLIST.md) |
| Live deployment in the series | Not yet |

Three words are used throughout:

- A recipe is one application folder with its Compose file and environment example.
- A flavor is the image set a recipe uses. `standard` selects upstream images. `dhi` selects Docker Hardened Images from `dhi.io` for the services that have one and keeps upstream images for the rest.
- `prepare` is a one-shot Compose service in every recipe. It creates the data directories, sets their ownership, and writes the configuration files the other services mount.

```text
applications/docker-recipes/
  standard/<application>/compose.yaml
  standard/<application>/.env.example
  dhi/<application>/compose.yaml
  dhi/<application>/.env.example
  verification/CHECKLIST.md
```

## Before you start

- Web ports bind to `127.0.0.1` only. Nothing is reachable from another machine until you put a reverse proxy with TLS in front of the stack. Four recipes publish extra ports on all interfaces because the protocol needs it: qBittorrent's torrent port, Syncthing's sync port, WireGuard's UDP port, and Stoat's voice ports. Open those in the host firewall on purpose.
- Docker Hardened Images are a paid Docker subscription feature. Pulling from `dhi.io` needs `docker login dhi.io` with an entitled account; without one the pull fails with an authorization error, so use the `standard` folder instead. Eight DHI folders contain no hardened image at all because none exists for that application: freshrss, jellyfin, navidrome, openwebui, qbittorrent, serpbear, syncthing, and wg-adguard. Each DHI environment example says what stays upstream.
- Three recipes download from the internet on first start, each pinned by version and SHA-256 checksum. Baserow fetches a Gunicorn wheel from PyPI. Zulip fetches a Debian dictionary package and a Pika wheel. Open WebUI fetches about 890 MB of embedding model from Hugging Face. The downloads are cached inside the deployment directory.
- `prepare` runs as root inside its container and changes ownership only inside the deployment directory. On a rootless Docker daemon, container root is your own account. On a rootful daemon it is real root; the recipes that hold your own files, Jellyfin and Syncthing, say in their environment example how ownership is handled.
- The local checks ran on a rootless daemon. A rootful daemon has not been tested.
- Addresses such as `example.com` and `admin@example.com` are documentation values. Replace them.

## Start an application

Copy the chosen recipe to a deployment directory outside this repository so generated data stays out of Git. On the Docker host, from the repository root, with `authentik` replaced by the folder you chose:

```sh
mkdir -p ~/deployments
cp -a applications/docker-recipes/standard/authentik ~/deployments/authentik-standard
cd ~/deployments/authentik-standard
cp .env.example .env
# Fill in secrets and deployment settings in .env.
docker compose run --rm prepare
docker compose up -d --wait
docker compose ps -a
```

Every command after the copy runs from that deployment directory. Some applications need more setup; the environment example says so. Image pins and flavor-specific defaults live in each Compose file, so nothing needs uncommenting to select DHI.

Use generated secrets; every empty secret has a generator command in the comment above it. Where an example leaves a third-party credential empty, such as Mira's OpenRouter key or Zulip's SMTP password, the stack starts without it and the related feature does not work.

Use an ordered stop and start to restart the whole stack with its existing data:

```sh
docker compose stop
docker compose up -d --wait
```

## Switching flavors or reusing data

Bind-mounted data must stay with the Compose deployment that created it. Stop the stack and back up its data before replacing its Compose file. Keep the whole deployment directory, including hidden configuration files and data directories. Replace the Compose file with the other flavor's file and review that flavor's environment example before reusing an existing `.env`, especially image overrides, data ownership, and runtime paths. Keeping the deployment directory name preserves the default Compose project name.

Do not point two running stacks at the same database or application data. When testing both flavors, use separate deployment directories, Compose project names, and host ports. Switching flavors can require different ownership or runtime paths; stop the stack before running its preparation step.

## Runtime compatibility fixes

Some recipes initialize application schemas or install a specific runtime fix before starting the app. Downloaded Python wheels and dictionary packages have fixed versions and SHA-256 checks. Generated files are mounted read-only into the application or database. Mira's callback patch also checks the exact original source before changing it.

[Batch A](verification/batch-a.md), [Batch B](verification/batch-b.md), and [Batch C](verification/batch-c.md) record why each fix exists and when it can be removed. Review these fixes when updating image pins, and repeat the application and restart checks.

## Verification

[The checklist](verification/CHECKLIST.md) records both flavors of all applications. The batch reports linked from it describe the checks performed and any failures or external prerequisites. Every one-shot job, `prepare` and the `*-init` services, should exit with code 0; every long-running container must report healthy.

Maintainers run the checks with the runner in `verification/`. It writes its working copies and results under `~/.cache/docker-recipes-verify/`, outside any deployment directory. On the Docker host, from the repository root:

```sh
python3 applications/docker-recipes/verification/verify.py static
python3 applications/docker-recipes/verification/verify.py run --app authentik
```

The static command renders all 44 recipes and checks matching application folders, image digest pins, healthcheck coverage, loopback port bindings, and that every application has a test spec. The run command starts each selected recipe with generated secrets, checks health, probes the web endpoint, scans logs, restarts the stack, and repeats the checks. Details are in [the verification README](verification/README.md).
