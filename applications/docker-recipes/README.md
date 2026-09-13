# Docker Compose recipes

Compose files and environment examples for 22 self-hosted applications, each in two image flavors. They are the source recipes for the application episodes. No per-application guide exists yet; the recipes carry their own instructions in each `.env.example`.

[Applications](../README.md) · [Episode index](../../episodes/README.md)

| Detail | Value |
|---|---|
| Status | Recipe library, no guide yet |
| Last local check | 2026-09-09, both flavors of all 22 applications, see [the checklist](verification/CHECKLIST.md) |
| Live deployment in the series | Not yet |

Each application has a separate Compose file and environment example for each image flavor:

```text
applications/docker-recipes/
  standard/<application>/compose.yaml
  standard/<application>/.env.example
  dhi/<application>/compose.yaml
  dhi/<application>/.env.example
  verification/CHECKLIST.md
```

`standard` selects upstream images. `dhi` selects Docker Hardened Images from `dhi.io` for supported services and keeps upstream images for the others. Pulling from `dhi.io` needs a Docker Hub account with access to hardened images; run `docker login dhi.io` before the first pull. Each DHI environment example says which services are hardened. The folder name does not mean every container uses a hardened image.

## Start an application

Copy the selected application folder to a deployment directory outside this checkout so generated data stays out of Git. Then follow the instructions at the top of its `.env.example`. On the Docker host, from the repository root:

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

Run `prepare` only when the application defines that service. Some applications require additional setup; follow their environment comments. Image pins and flavor-specific defaults live in each Compose file, so no image block needs to be uncommented to select DHI.

Use generated secrets. Placeholder API credentials are suitable only for local startup checks where the application supports them. They cannot authenticate external services.

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

The batch reports record why each fix exists and when it can be removed. Review these fixes when updating image pins, and repeat the application and restart checks.

## Verification

[The checklist](verification/CHECKLIST.md) records both flavors of all applications. The linked batch reports describe the checks performed and any failures or external prerequisites. A completed initializer should exit with code 0; every long-running container must report healthy.

Maintainers run the checks with the runner in `verification/`. On the workstation or Docker host, from the repository root:

```sh
python3 applications/docker-recipes/verification/verify.py static
python3 applications/docker-recipes/verification/verify.py run --app authentik
```

The static command renders all 44 Compose files and checks matching application folders, image digest pins, healthcheck coverage, loopback port bindings, and that every application has a test spec. The run command starts each selected recipe with generated secrets, checks health, probes the web endpoint, scans logs, restarts the stack, and repeats the checks. Details are in [the verification README](verification/README.md).
