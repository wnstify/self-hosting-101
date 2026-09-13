# Authentik, Nextcloud, DocuSeal, NocoDB, Vaultwarden, Mira, n8n and AppFlowy

Tests use separate Compose projects and disposable bind mounts outside this repository. Nextcloud uses a disk-backed directory because the test host mounts `/tmp` as tmpfs. Secrets are generated for each test. Both recipes keep application images upstream and use their own dependency and prepare image defaults.

A successful runtime check requires `prepare` to exit 0, `up --wait` to succeed, all persistent services to report healthy, initialization jobs to exit 0, an HTTP response, and a successful restart with retained data. Logs are inspected separately; health alone does not prove that an application has no errors.

| Application | Standard | DHI | Notes |
| --- | --- | --- | --- |
| Authentik | Healthy, HTTP 302, API group persisted, clean logs | Healthy, HTTP 302, API group persisted, clean logs | Initial upstream image pull failed with `lease does not exist: not found`; retry succeeded. |
| Nextcloud | Healthy, WebDAV upload persisted, empty app log | Healthy, WebDAV upload persisted, empty app log | Use disk-backed bind mounts for installation. Initial rsync failed with tmpfs bind mounts; the disk-backed retry passed. |
| DocuSeal | Healthy, clean error logs, account setup and retained login passed | Healthy, clean error logs, interrupted initialization and retained login passed | Base schema now initializes before the application. |
| NocoDB | Healthy, admin login and invite-only settings persisted | Healthy, admin login and invite-only settings persisted | No application errors. |
| Vaultwarden | Healthy, admin login before and after restart passed | Healthy, admin login before and after restart passed | No application errors. |
| Mira | Healthy, user persisted, clean error and shutdown logs | Healthy, user persisted, clean error and shutdown logs | Placeholder GitHub App credentials and OpenRouter key only verify local startup. Real repository access, webhooks, reviews and indexing require valid external credentials. |
| n8n | Healthy, saved workflow executed before and after restart | Healthy, saved workflow executed before and after restart | External integrations need their own credentials. |
| AppFlowy | Healthy, regular user/workspace/object persisted, clean error logs | Healthy, regular user/workspace/object persisted, clean error logs | Empty GoTrue migration table initialized before first startup. |

## Image coverage

| Application | DHI services | Upstream services |
| --- | --- | --- |
| Authentik | PostgreSQL, database initialization, prepare | Server, worker |
| Nextcloud | PostgreSQL, database initialization, Redis, nginx, prepare | App, cron |
| DocuSeal | PostgreSQL, database initialization, Redis, prepare | DocuSeal, schema initialization |
| NocoDB | PostgreSQL, database initialization, Redis, prepare | App, worker, administrator initialization |
| Vaultwarden | PostgreSQL, database initialization, prepare | Vaultwarden |
| Mira | PostgreSQL, database initialization, prepare | Mira, source patch initialization |
| n8n | PostgreSQL, database initialization, prepare | n8n, runner |
| AppFlowy | pgvector, auth schema initialization, Redis, nginx, prepare | GoTrue, cloud, worker, web, administrator frontend, MinIO |

DHI Redis and nginx use UID/GID 65532. Their Compose defaults, environment examples and prepare ownership commands agree. PostgreSQL keeps UID/GID 70 in both recipes.

## Runtime caveats

- An initial Authentik test used `docker compose restart`, which restarts PostgreSQL while clients still run and caused transient shutdown warnings. The final checks use `docker compose stop` followed by `up --wait`. Both recipes passed that final check with clean logs and a persisted API-created group.
- Initial readiness probes can fail while an application creates its database. This is distinct from a service remaining unhealthy after its startup grace period.
- Standard PostgreSQL emitted an Alpine locale initialization notice. Both Nextcloud recipes emitted PostgreSQL local socket trust initialization notices, plus Redis warning that the host has `vm.overcommit_memory=0`. The same database and Redis notices appeared in other fresh stacks using those images. No application errors appeared; Nextcloud's own log was empty.
- Fixed DocuSeal 3.2.3 first-boot missing-table errors by running the pinned image's first three migrations with `ActiveRecord::MigrationContext.up(20230515193039)` before the application starts. This creates the tables its storage initializer needs. The app runs the remaining migrations. The upward-only migration call skips completed migrations and does not reset existing data.
- Mira 0.4.0 logs a GitHub installation lookup warning with placeholder credentials because GitHub returns HTTP 404. Its unconditional vulnerability poller also logs `asyncio.exceptions.CancelledError` during graceful shutdown: the shipped callback calls `t.exception()` before checking `t.cancelled()`. The recipes now apply a source override that checks cancellation before reading exceptions in both background callbacks. The patch verifies the pinned module SHA-256 and exact replacement context, writes the module and its Apache license atomically, and mounts only that module read-only. Both current recipes passed cold startup, admin authentication, API-created user login after stop/up, the callback regression inside the running container, and final graceful shutdown. Full logs contain no errors or exceptions; the documented placeholder installation warning remains.
- Checked the newer upstream [Mira v0.9.0 server](https://github.com/miracodeai/mira/blob/v0.9.0/src/mira/platforms/server.py): it retains the same cancellation callback ordering. Updating to that supported release would not resolve the shutdown error. The tested 0.4.0 pin remains unchanged.

- n8n checks created an owner and saved a Manual Trigger to Code workflow. The external JavaScript runner returned `{"answer":42}` before and after stop/up. Final cold runs had no application errors or shutdown errors. The informational message `Error tracking disabled because this release is older than 6 weeks` refers to telemetry. One earlier standard run caught a PostgreSQL readiness connection during shutdown, producing `FATAL: the database system is shutting down`; the application had already stopped. Its repeat passed with clean shutdown logs. Poll execution summaries until completion before fetching execution details; the pinned upstream API throws when details are requested before result data exists.


- AppFlowy first startup queried GoTrue's absent `auth.schema_migrations` table and logged a PostgreSQL error. Both recipes now create only its empty native table, with `version varchar(14)` as the primary key, before GoTrue starts. The existing `appflowy` database role owns the schema and table. No migration versions are seeded and existing data is retained. Both cold tests ran all 53 recorded GoTrue migrations and retained those records after stop/up.
- AppFlowy checks used the bootstrap admin to create a regular account through GoTrue's admin API. The regular account logged in, created a workspace and retained it after restart. A MinIO object also survived restart. The system administrator cannot own a workspace; use a regular account for that workflow. Both final runs had all nine persistent services healthy, the schema initializer exited 0, and full logs including shutdown had no actual errors.
- AppFlowy still emits upstream warnings for a nested migration transaction and the deprecated GoTrue admin-group setting. MinIO warns about its single-host storage layout, and the web supervisor labels normal SIGTERM shutdown as a warning. Redis also reports this host's disabled memory overcommit setting. These warnings did not prevent the tested operations or retained-data startup.


## Mira callback patch

`check_mira_callback.py` extracts the backfill and poller callbacks from a supplied module and runs it with cancelled, successful and failed tasks. Both original callbacks failed with `CancelledError`. The patched source passed, including preservation of real exception logging.

`source-patch` stops deployment if the source checksum changes. When upgrading Mira, check the upstream callback first. Once the release handles cancelled tasks correctly, remove the source-patch service, its dependency and module bind mount, and the runtime-patches preparation commands together. Keep the cancellation regression check while verifying the new image.

Both Mira initializers passed interrupted-write recovery with mode-0444 `webhooks.py.next` and `LICENSE.next` files. The test extracted each recipe's actual source-patch code and ran it as UID 1000 with capabilities dropped in a cached Python helper, using the saved source whose SHA-256 matches the recipe guard. The old code failed with `PermissionError`; the fixed code removed stale temporary files, regenerated both assets, and passed a second initialization.

Both resulting modules exactly match the earlier runtime-tested modules, and the cancellation, success and real-failure callback checks pass. Recovery logs and results are kept outside this repository.
