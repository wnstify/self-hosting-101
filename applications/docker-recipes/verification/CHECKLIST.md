# Stack verification checklist

This document is the maintainers' record. Deployers need only the results table.

Success requires both flavors of every application to pass the checks below. A running container alone is insufficient. Record failures and external prerequisites rather than marking them passed.

## Checks for each application and flavor

- Compose renders with a completed environment file and selects the intended images.
- Preparation and initialization jobs finish with exit code 0.
- Every long-running container reports healthy, with no unexpected exits or restarts.
- The application responds on its published endpoint and passes the recorded smoke check.
- Startup and steady-state logs have been reviewed; no unresolved application errors remain.
- Restarting the stack preserves its initialized data and returns it to healthy status.
- External integrations tested with real credentials are identified separately from placeholder checks.
- Temporary containers and test data are removed after evidence is recorded.

One-shot preparation and migration jobs should exit successfully. They are not expected to remain running or report a health status.

## Results

All 44 recipes passed local startup, application and retained-data lifecycle checks. Final log audits found no unresolved error-level events or unhandled tracebacks. This does not mean silent logs: documented warnings and Baserow's INFO socket-close diagnostic remain.

A caveat does not turn a failed check into a pass.

| Application | Standard | DHI | Evidence and caveats |
| --- | --- | --- | --- |
| appflowy | Local checks passed | Local checks passed | [Batch A](batch-a.md). Nine healthy services, 53 retained auth migrations, regular-user workspace and MinIO object persistence passed; lifecycle logs clean. |
| authentik | Local checks passed | Local checks passed | [Batch A](batch-a.md). Authenticated group creation and persistence passed; final ordered restart logs clean. |
| baserow | Local checks passed; INFO diagnostic | Local checks passed; INFO diagnostic | [Batch B](batch-b.md). Full template import, authenticated table/row operations and persistence passed. Gunicorn 24.1.0 removed ERROR-level shutdown messages; an INFO socket-close diagnostic remains documented. |
| dockhand | Local checks passed | Local checks passed | [Batch B](batch-b.md). Packaged migration initialization fixed first-boot SQL error; administrator login, Docker connection and persistence passed. |
| docuseal | Local checks passed | Local checks passed | [Batch A](batch-a.md). Packaged pre-migrations removed first-boot SQL error; setup, persisted login and interrupted migration recovery passed. |
| freshrss | Local checks passed | Local checks passed | [Batch C](batch-c.md). Administrator setup and authenticated API login passed before and after restart. |
| jellyfin | Local checks passed | Local checks passed | [Batch C](batch-c.md). Administrator login and library creation persisted after restart; upstream warnings remain documented. |
| meshcentral | Local checks passed | Local checks passed | [Batch B](batch-b.md). Live MongoDB connection probe, administrator authentication, database ping and retained-data restart passed; stale-socket negative test passed. |
| mira | Local checks passed | Local checks passed | [Batch A](batch-a.md). Guarded callback patch passed regression checks, authenticated user persistence and full shutdown logs; placeholder GitHub warnings remain. |
| n8n | Local checks passed | Local checks passed | [Batch A](batch-a.md). Owner login, saved workflow and real external-runner Code output passed before and after restart; final lifecycle logs clean. |
| navidrome | Local checks passed | Local checks passed | [Batch C](batch-c.md) and [functional checks](functional-checks.md). Administrator setup, generated WAV scan, exact streamed bytes and retained-data restart passed. |
| nextcloud | Local checks passed | Local checks passed | [Batch A](batch-a.md). WebDAV uploads and exact file contents persisted after restart in both flavors; application logs clean. |
| nocodb | Local checks passed | Local checks passed | [Batch A](batch-a.md). App/worker health, administrator login and invite-only settings persisted after restart; application logs clean. |
| openwebui | Local checks passed | Local checks passed | [Batch C](batch-c.md). Administrator login and chat creation/retrieval persisted after restart; model-provider inference remains unverified. |
| qbittorrent | Local checks passed | Local checks passed | [Batch C](batch-c.md) and [functional checks](functional-checks.md). Authenticated API, category/settings persistence and application logs passed; no public torrents used. |
| serpbear | Local checks passed | Local checks passed | [Batch C](batch-c.md). Authenticated domains API and restart passed; Node deprecation warning recorded. |
| stoat | Local checks passed | Local checks passed | [Batch C](batch-c.md). Fifteen healthy services, account/message/attachment persistence and full lifecycle logs passed; live MongoDB probe, primary-election wait and direct web startup verified. |
| syncthing | Local checks passed | Local checks passed | [Batch C](batch-c.md) and [functional checks](functional-checks.md). Standard/DHI local peers transferred generated files both ways across a retained-data restart; hashes matched. |
| uptime-kuma | Local checks passed | Local checks passed | [Batch B](batch-b.md). Administrator creation and WebSocket login persisted after restart; MariaDB host/client warnings documented. |
| vaultwarden | Local checks passed | Local checks passed | [Batch A](batch-a.md). Administrator authentication passed before and after retained-data restart; application logs clean. |
| wg-adguard | Local checks passed | Local checks passed | [Batch C](batch-c.md). Initializer verifies real DNS before VPN startup; fresh setup, first shutdown without manual queries, persisted restart and final logs passed. |
| zulip | Local checks passed | Local checks passed | [Batch C](batch-c.md). Administrator/message persistence, dictionary-backed stemming search, actual queue consumers and final shutdown logs passed after dependency, supervisor and worker fixes. |

## Runner results

`verify.py run` covered all 44 recipes on 2026-09-09: generated secrets, prepare, healthy startup, endpoint probe, log scan, ordered restart, and the same checks again. Every recipe passed. Allowed log lines are listed per application under `apps/` with the reason for each.

## Scope

Recorded on 2026-09-09 on a Linux amd64 test host with Docker Engine 29.6.0 and Compose 5.1.2, using the rootless daemon. Large test deployments use disk-backed directories because that host mounts `/tmp` in RAM.

These checks cover isolated local deployments on that test host. A rootful Docker daemon has not been tested. Placeholder credentials can verify startup where supported, but cannot verify authenticated third-party operations, email delivery, public TLS, or production traffic. Eight DHI folders contain no `dhi.io` image at all and are upstream fallbacks: freshrss, jellyfin, navidrome, openwebui, qbittorrent, serpbear, syncthing, and wg-adguard. The other fourteen harden dependencies and keep the application image upstream unless their environment example says otherwise.

## Changes since the check

- 2026-09-13, publication review: the Jellyfin `prepare` step now gives the media directories to the owner of the deployment directory instead of container root, and the Syncthing container user became configurable so its data stays yours on a rootful daemon. Neither change has been rerun through `verify.py`. Environment comments and the README changed; no image pin changed.
